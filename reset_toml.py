def reset_toml(file_path):
    with open(file_path, 'r') as file:
        lines = file.readlines()

    in_addresses_section = False
    address_modified = False

    with open(file_path, 'w') as file:
        for line in lines:
            if line.strip() == '[addresses]':
                in_addresses_section = True
            elif in_addresses_section and '=' in line and not address_modified:
                key = line.split('=')[0].strip()
                file.write('#' + line)  # Comment out the existing line
                file.write(f'{key} = "0x"\n')  # Add new line with '0x'
                address_modified = True
                continue
            elif line.strip().startswith('[') and in_addresses_section:
                in_addresses_section = False

            file.write(line)

# Replace 'path_to_file.toml' with the actual path to your Move.toml file
reset_toml('memechan/Move.toml')