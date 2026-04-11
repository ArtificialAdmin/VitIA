import os
import re
import shutil

base_dir = "frontend/lib"

file_mapping = {
    "pages/auth/login_page.dart": "features/auth/presentation/pages/login_page.dart",
    "pages/auth/register_page.dart": "features/auth/presentation/pages/register_page.dart",
    "pages/tutorial/tutorial_page.dart": "features/tutorial/presentation/pages/tutorial_page.dart",
    "pages/capture/foto_page.dart": "features/coleccion/presentation/pages/foto_page.dart",
    "pages/gallery/catalogo_page.dart": "features/biblioteca/presentation/pages/catalogo_page.dart",
    "pages/gallery/detalle_variedad_page.dart": "features/biblioteca/presentation/pages/detalle_variedad_page.dart",
    "pages/gallery/detalle_coleccion_page.dart": "features/coleccion/presentation/pages/detalle_coleccion_page.dart",
    "pages/gallery/user_variety_detail_page.dart": "features/coleccion/presentation/pages/user_variety_detail_page.dart",
    "pages/library/create_post_page.dart": "features/foro/presentation/pages/create_post_page.dart",
    "pages/library/custom_camera_page.dart": "features/foro/presentation/pages/custom_camera_page.dart",
    "pages/library/foro_page.dart": "features/foro/presentation/pages/foro_page.dart",
    "pages/library/post_detail_page.dart": "features/foro/presentation/pages/post_detail_page.dart",
    "pages/map/map_page.dart": "features/mapa/presentation/pages/map_page.dart",
    "pages/main_layout/home_page.dart": "features/home/presentation/pages/home_page.dart",
    "pages/main_layout/inicio_screen.dart": "features/home/presentation/pages/inicio_screen.dart",
    "pages/main_layout/perfil_page.dart": "features/usuarios/presentation/pages/perfil_page.dart",
    "pages/main_layout/edit_profile_page.dart": "features/usuarios/presentation/pages/edit_profile_page.dart",
}

# Auto-add any missing files in mapped dirs just in case
for folder in ["pages/auth", "pages/map", "pages/tutorial", "pages/capture", "pages/gallery", "pages/library", "pages/main_layout"]:
    folder_path = os.path.join(base_dir, folder)
    if os.path.exists(folder_path):
        for f in os.listdir(folder_path):
            if f.endswith('.dart'):
                key = f"{folder}/{f}"
                if key not in file_mapping:
                    # Generic mapping just to not lose them
                    if "auth" in folder:
                        file_mapping[key] = f"features/auth/presentation/pages/{f}"
                    elif "map" in folder:
                        file_mapping[key] = f"features/mapa/presentation/pages/{f}"
                    elif "tutorial" in folder:
                        file_mapping[key] = f"features/tutorial/presentation/pages/{f}"
                    else:
                        file_mapping[key] = f"features/misc/presentation/pages/{f}"

def convert_to_absolute_imports(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    rel_path = os.path.relpath(file_path, base_dir)
    
    def replacer(match):
        import_path = match.group(1)
        if import_path.startswith('package:') or import_path.startswith('dart:'):
            return match.group(0)
            
        norm_dir = os.path.dirname(rel_path) 
        abs_import = os.path.normpath(os.path.join(norm_dir, import_path)).replace('\\', '/')
        # Si por alguna razón escapa lib/ (ej. lib/main.dart imports), ignoramos
        if abs_import.startswith(".."):
            return match.group(0)
            
        return f"import 'package:vinas_mobile/{abs_import}';"
    
    new_content = re.sub(r"import\s+'([^']+)'\s*;", replacer, content)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

# 0. Clean dummy features
for feat in ["library", "gallery", "capture"]:
    d = os.path.join(base_dir, "features", feat)
    if os.path.exists(d):
        shutil.rmtree(d)

# 1. Convert all
for root, _, files in os.walk(base_dir):
    for f in files:
        if f.endswith('.dart'):
            convert_to_absolute_imports(os.path.join(root, f))

# 2. Replace using mapping
def update_imports_in_all_files():
    for root, _, files in os.walk(base_dir):
        for f in files:
            if f.endswith('.dart'):
                file_path = os.path.join(root, f)
                with open(file_path, 'r', encoding='utf-8') as fld:
                    content = fld.read()
                
                new_content = content
                for old_path, new_path in file_mapping.items():
                    old_dart_path = "package:vinas_mobile/" + old_path.replace("\\", "/")
                    new_dart_path = "package:vinas_mobile/" + new_path.replace("\\", "/")
                    new_content = new_content.replace(old_dart_path, new_dart_path)
                
                with open(file_path, 'w', encoding='utf-8') as fld:
                    fld.write(new_content)

update_imports_in_all_files()

# 3. Move files
for old_path, new_path in file_mapping.items():
    old_full = os.path.join(base_dir, old_path)
    new_full = os.path.join(base_dir, new_path)
    
    if os.path.exists(old_full):
        os.makedirs(os.path.dirname(new_full), exist_ok=True)
        shutil.move(old_full, new_full)
        print(f"Moved {old_path} -> {new_path}")

shutil.rmtree(os.path.join(base_dir, "pages"), ignore_errors=True)
print("Migration script completed successfully.")
