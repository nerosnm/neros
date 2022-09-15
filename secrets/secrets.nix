let
  inherit (builtins) mapAttrs readFile;

  # Public keys of specific machines.
  taygeta = readFile ../keys/taygeta.pub;

  # Each of the secrets is given a list of public keys that should be used to 
  # encrypt them. Right now, only the machine-specific keys from above are added 
  # to the list for each secret, because these are the keys that will not 
  # necessarily be given access to every secret.
  secrets = {
    "pounce-auth.pem.age".publicKeys = [ taygeta ];
    "pounce-client.pem.age".publicKeys = [ taygeta ];
  };

  # Public key of an age-plugin-yubikey key, the counterpart to the keygrip 
  # `./identities/soren-yubikey.txt`.
  #
  # This is not my main Yubikey SSH key (`../keys/soren.pub`), because that 
  # can't be used with agenix at the moment.
  soren-yubikey = "age1yubikey1q2rz3aqs37q2t2asrpvf274pukm6ez6kv4cc0wpmft5k0fm009aj66hrlez";

  # Keys that should always be able to access every secret, so they can be used 
  # to access and re-encrypt secrets.
  general = [
    soren-yubikey
  ];
in
# Map each secret's `publicKeys` list to a new one that also includes `general`.
mapAttrs
  (_: secret: { publicKeys = secret.publicKeys ++ general; })
  secrets
