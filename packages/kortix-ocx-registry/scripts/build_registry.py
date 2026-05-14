#!/usr/bin/env python3

from __future__ import annotations

import json
import shutil
import zipfile
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"
PUBLIC_DIR = ROOT / "public"
COMPONENTS_DIR = PUBLIC_DIR / "components"
PUBLIC_SKILLS_DIR = PUBLIC_DIR / "skills"
DIST_DIR = PUBLIC_DIR / "dist"
WORKER_PATH = ROOT / "worker" / "index.ts"

NAME = "kortix-ocx-registry"
VERSION = "1.0.0"
NAMESPACE = "kortix"
AUTHOR = "kortix"
DESCRIPTION = "Kortix Marketplace - Skills for Kortix AI Agents"
REGISTRY_URL = "https://kortix-registry-6om.pages.dev"
REPOSITORY_URL = "https://github.com/kortix-ai/kortix-ocx-registry"
OCX_SCHEMA = "https://ocx.kdco.dev/schemas/ocx.json"
REGISTRY_SCHEMA = "https://registry.kortix.com/schema.json"


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def parse_frontmatter_value(raw: str) -> object:
    value = raw.strip()
    if not value:
        return ""
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1].strip()
        if not inner:
            return []
        return [item.strip().strip("\"'") for item in inner.split(",") if item.strip()]
    if (value.startswith('"') and value.endswith('"')) or (
        value.startswith("'") and value.endswith("'")
    ):
        return value[1:-1]
    return value


def parse_skill_metadata(skill_file: Path) -> tuple[dict[str, object], str]:
    text = skill_file.read_text(encoding="utf-8")
    lines = text.splitlines()
    metadata: dict[str, object] = {}

    if lines and lines[0].strip() == "---":
        index = 1
        while index < len(lines):
            line = lines[index]
            if line.strip() == "---":
                body = "\n".join(lines[index + 1 :])
                return metadata, body
            if ":" in line:
                key, value = line.split(":", 1)
                metadata[key.strip()] = parse_frontmatter_value(value)
            index += 1

    return metadata, text


def extract_heading(markdown: str) -> str | None:
    for line in markdown.splitlines():
        stripped = line.strip()
        if stripped.startswith("# "):
            return stripped[2:].strip()
    return None


def prettify_component_name(name: str) -> str:
    label = name.removeprefix("skill-").replace("-", " ").replace("_", " ")
    return " ".join(word.capitalize() for word in label.split())


def clean_generated_directories() -> None:
    for directory in (COMPONENTS_DIR, PUBLIC_SKILLS_DIR, DIST_DIR):
        if directory.exists():
            shutil.rmtree(directory)
        directory.mkdir(parents=True, exist_ok=True)


def copy_tree(files: list[Path], source_root: Path, destination_root: Path) -> None:
    for file_path in files:
        relative_path = file_path.relative_to(source_root)
        destination = destination_root / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(file_path, destination)


def build_zip(component_name: str, files: list[Path], source_root: Path) -> None:
    archive_path = DIST_DIR / f"{component_name}.zip"
    with zipfile.ZipFile(
        archive_path, "w", compression=zipfile.ZIP_DEFLATED
    ) as archive:
        for file_path in files:
            relative_path = file_path.relative_to(source_root).as_posix()
            archive.write(file_path, arcname=f"skills/{component_name}/{relative_path}")


def build_skills() -> tuple[
    list[dict[str, object]], list[dict[str, object]], list[dict[str, object]]
]:
    index_components: list[dict[str, object]] = []
    registry_skills: list[dict[str, object]] = []
    component_entries: list[dict[str, object]] = []

    skill_directories = sorted(
        path
        for path in SKILLS_DIR.iterdir()
        if path.is_dir() and (path / "SKILL.md").exists()
    )

    for skill_dir in skill_directories:
        component_name = skill_dir.name
        metadata, body = parse_skill_metadata(skill_dir / "SKILL.md")
        description = str(metadata.get("description") or "").strip()
        display_name = str(
            metadata.get("displayName")
            or extract_heading(body)
            or prettify_component_name(component_name)
        )
        tags = metadata.get("tags") if isinstance(metadata.get("tags"), list) else []
        files = sorted(path for path in skill_dir.rglob("*") if path.is_file())
        file_paths = [
            f"skills/{component_name}/{path.relative_to(skill_dir).as_posix()}"
            for path in files
        ]

        copy_tree(files, skill_dir, PUBLIC_SKILLS_DIR / component_name)
        copy_tree(
            files,
            skill_dir,
            COMPONENTS_DIR / component_name / "skills" / component_name,
        )
        build_zip(component_name, files, skill_dir)

        component_manifest = {
            "name": component_name,
            "description": description,
            "repository": f"{REPOSITORY_URL}.git",
            "dist-tags": {
                "latest": VERSION,
            },
            "versions": {
                VERSION: {
                    "name": component_name,
                    "version": VERSION,
                    "description": description,
                    "type": "ocx:skill",
                    "files": file_paths,
                    "dist": {
                        "tarball": f"{REGISTRY_URL}/dist/{component_name}.zip",
                    },
                    "repository": {
                        "type": "git",
                        "url": f"{REPOSITORY_URL}.git",
                    },
                }
            },
        }

        write_json(COMPONENTS_DIR / f"{component_name}.json", component_manifest)

        index_components.append(
            {
                "name": component_name,
                "version": VERSION,
                "type": "ocx:skill",
                "description": description,
            }
        )
        registry_skills.append(
            {
                "name": component_name,
                "displayName": display_name,
                "description": description,
                "author": AUTHOR,
                "tags": tags,
                "path": f"skills/{component_name}",
            }
        )
        component_entries.append(
            {
                "name": component_name,
                "path": f"skills/{component_name}",
            }
        )

    return index_components, registry_skills, component_entries


def build_ocx_document(component_entries: list[dict[str, object]]) -> dict[str, object]:
    return {
        "$schema": OCX_SCHEMA,
        "namespace": NAMESPACE,
        "author": AUTHOR,
        "name": NAME,
        "description": DESCRIPTION,
        "registries": {
            "kortix": {
                "url": REGISTRY_URL,
            }
        },
        "lockRegistries": False,
        "skipCompatCheck": False,
        "components": {
            "skills": [entry["path"] for entry in component_entries],
        },
    }


def build_worker(
    index_payload: dict[str, object],
    registry_payload: dict[str, object],
    ocx_payload: dict[str, object],
) -> None:
    worker_source = """export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === '/' || url.pathname === '/registry.json') {
      return jsonResponse(registryJson);
    }

    if (url.pathname === '/index.json') {
      return jsonResponse(indexJson);
    }

    if (url.pathname === '/ocx.json' || url.pathname === '/ocx.jsonc') {
      return jsonResponse(ocxJson);
    }

    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
        },
      });
    }

    return new Response('Not Found', { status: 404 });
  },
};

function jsonResponse(payload) {
  return new Response(JSON.stringify(payload, null, 2), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'public, max-age=60',
    },
  });
}

const indexJson = __INDEX_JSON__;

const registryJson = __REGISTRY_JSON__;

const ocxJson = __OCX_JSON__;
"""

    worker_source = worker_source.replace(
        "__INDEX_JSON__", json.dumps(index_payload, indent=2)
    )
    worker_source = worker_source.replace(
        "__REGISTRY_JSON__", json.dumps(registry_payload, indent=2)
    )
    worker_source = worker_source.replace(
        "__OCX_JSON__", json.dumps(ocx_payload, indent=2)
    )
    WORKER_PATH.write_text(worker_source, encoding="utf-8")


def main() -> None:
    SKILLS_DIR.mkdir(parents=True, exist_ok=True)
    PUBLIC_DIR.mkdir(parents=True, exist_ok=True)
    clean_generated_directories()

    index_components, registry_skills, component_entries = build_skills()

    index_payload = {
        "name": NAME,
        "version": VERSION,
        "namespace": NAMESPACE,
        "author": AUTHOR,
        "description": DESCRIPTION,
        "components": index_components,
    }

    registry_payload = {
        "$schema": REGISTRY_SCHEMA,
        "version": VERSION,
        "name": NAME,
        "description": DESCRIPTION,
        "updated": date.today().isoformat(),
        "registryUrl": REGISTRY_URL,
        "repository": REPOSITORY_URL,
        "skills": registry_skills,
    }

    ocx_payload = build_ocx_document(component_entries)

    write_json(ROOT / "registry.json", index_payload)
    write_json(PUBLIC_DIR / "index.json", index_payload)
    write_json(PUBLIC_DIR / "registry.json", registry_payload)
    write_json(ROOT / "ocx.jsonc", ocx_payload)
    write_json(PUBLIC_DIR / "ocx.json", ocx_payload)
    build_worker(index_payload, registry_payload, ocx_payload)


if __name__ == "__main__":
    main()
