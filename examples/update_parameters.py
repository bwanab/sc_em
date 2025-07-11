#!/usr/bin/env python3

import json
import os
import glob

def load_mapping():
    """Load the parameter mapping from the mapping file."""
    mapping_path = '/Users/bill/src/modsynth_gui_phx/parameter_rename_mapping.json'
    with open(mapping_path, 'r') as f:
        return json.load(f)

def update_file(file_path, mapping):
    """Update a single JSON file with the correct parameter names."""
    print(f"Processing {file_path}...")
    
    with open(file_path, 'r') as f:
        data = json.load(f)
    
    changes_made = False
    
    # Update connections
    for connection in data.get('connections', []):
        from_node = connection.get('from_node', {})
        node_name = from_node.get('name', '')
        param_name = from_node.get('param_name', '')
        
        # Check if this node type has parameter mappings
        if node_name in mapping:
            node_mapping = mapping[node_name]
            old_to_new = node_mapping.get('old_to_new', {})
            
            # If the current param_name is in the old_to_new mapping, update it
            if param_name in old_to_new:
                new_param_name = old_to_new[param_name]
                print(f"  Updating {node_name}: {param_name} -> {new_param_name}")
                from_node['param_name'] = new_param_name
                changes_made = True
    
    # Save the file if changes were made
    if changes_made:
        with open(file_path, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"  Changes saved to {file_path}")
    else:
        print(f"  No changes needed for {file_path}")
    
    return changes_made

def main():
    """Main function to update all JSON files."""
    mapping = load_mapping()
    examples_dir = '/Users/bill/src/sc_em/examples'
    
    # Get all JSON files
    json_files = glob.glob(os.path.join(examples_dir, '*.json'))
    
    total_files = len(json_files)
    files_updated = 0
    
    print(f"Found {total_files} JSON files to process...")
    
    for json_file in sorted(json_files):
        if update_file(json_file, mapping):
            files_updated += 1
    
    print(f"\nSummary: {files_updated} out of {total_files} files were updated.")

if __name__ == '__main__':
    main()