from py4wsl import WSL

# Initialize with your distribution name
wsl = WSL(distro='kali-linux')  # Replace 'Ubuntu' with your distro (check with `wsl --list`)

# Launch the command (wraps WslLaunch)
result = wsl.launch('ls -l /home')

# Print output
print("STDOUT:", result['stdout'])
print("STDERR:", result['stderr'])
print("Exit Code:", result['exit_code'])

