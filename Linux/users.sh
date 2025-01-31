#!/bin/bash
# Change passwords for non-root users and lock non-interactive accounts

# Get non-root users (UID >= 1000, exclude 'nobody')
USERS=$(awk -F: '$3 >= 1000 && $1 != "nobody" && $1 != "root" {print $1}' /etc/passwd)

if [ -z "$USERS" ]; then
  echo "No non-root users found. Exiting."
  exit 1
fi

# Prompt for password (hidden input)
read -sp "Enter a STRONG password for all non-root users: " PASSWORD
echo
read -sp "Confirm password: " CONFIRM_PASSWORD
echo

# Verify password match
if [ "$PASSWORD" != "$CONFIRM_PASSWORD" ]; then
  echo "Passwords do not match! Exiting."
  exit 1
fi

# Change passwords for all non-root users
for USER in $USERS; do
  echo "Changing password for: $USER"
  echo "$USER:$PASSWORD" | sudo chpasswd
done

echo "All non-root user passwords updated!"

# Lock non-interactive accounts (no login shell)
NON_INTERACTIVE_USERS=$(awk -F: '$7 !~ /(\/bin\/.*sh|\/bin\/bash|\/bin\/zsh)/ {print $1}' /etc/passwd)

for USER in $NON_INTERACTIVE_USERS; do
  if [[ "$USER" != "root" && "$USER" != "nobody" ]]; then
    echo "Locking non-interactive account: $USER"
    sudo passwd -l "$USER"
  fi
done

echo "All non-interactive accounts locked!"
