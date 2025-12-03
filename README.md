git clone <your_repo>
cd my2fa
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt


my2fa init --gpg-recipient YOURKEYID
my2fa add gmail-main
my2fa list

show codes:
my2fa code gmail-main
my2fa code --all


backup:
my2fa backup --output backup-2025-01-01.gpg


workflow:
1. compress
Compress-Archive -Path "D:\secrets" -DestinationPath "D:\secrets.zip"
Or
zip -r secrets.zip secrets/

2. del plain text files
Remove-Item "D:\secrets" -Recurse -Force

3. encrypt zip file
**get the public key from usb: gpg --import X:\publickey.asc

gpg --encrypt --recipient YOURKEYID "D:\secrets.zip"

4. delete plain text zip file
Remove-Item "D:\secrets.zip" -Force

5. decrypt (safe decryption)
**disable GPG agent key caching
in cmd: %APPDATA%\gnupg\gpg-agent.conf
add: default-cache-ttl 1
     max-cache-ttl 1
restart: gpgconf --kill gpg-agent
--> key does not stay in memory

import key:
gpg --import X:\private-master.key
gpg --import X:\private-subkeys.key
gpg --import-ownertrust X:\ownertrust.txt
decrypt:
gpg --decrypt "D:\secrets.zip.gpg" > "D:\secrets.zip"

6. unzip
Expand-Archive -Path "D:\secrets.zip" -DestinationPath "D:\secrets"

7. after you done editing:
gpg --delete-secret-keys YOURKEYID
restart agent: gpgconf --kill gpg-agent

# how to get yourkeyid:
gpg --list-keys
the pub long key or its last 8 chars is the keyid


# how to generate key
gpg --full-generate-key
RSA -> ONLY use sign + Certify(s,c)-> pure primary key
key size : 4096
expiration: 2y
identity: fake everything
passphrase: 16-24+ chars
create encryption subkey: gpg --edit-key YOURKEYID
then inside gpg prompt: addkey -> RSA ->4096 ->2y -> save
now we have: primary key (s,c) + subkey (e)


# back up keys
insert usb then run: 

gpg --export-secret-keys YOURKEYID > X:\gpg-master-private.key
gpg --export-secret-subkeys YOURKEYID > X:\gpg-subkeys.key
gpg --export-ownertrust > X:\ownertrust.txt


# del keys from computer
gpg --delete-secret-keys YOURKEYID
gpg --delete-keys YOURKEYID

# verify no keys in computer
gpg --list-secret-keys



