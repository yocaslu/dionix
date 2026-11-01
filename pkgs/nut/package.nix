# NUT (blawar/nut): servidor de títulos de Nintendo Switch para o Tinfoil.
# O nut.py troca o diretório atual para a própria pasta e grava lá dentro, então
# o pacote só guarda o código; o serviço (modules/nixos/switch-nut.nix) copia
# para uma pasta gravável antes de rodar. Só o modo servidor (-S) é usado: a
# interface gráfica (PyQt5) fica de fora.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  python3,
}:
let
  python = python3.withPackages (
    ps: with ps; [
      asn1
      beautifulsoup4
      certifi
      colorama
      filelock
      flask
      google-api-python-client
      google-auth-oauthlib
      humanize
      pillow
      pycryptodome
      pycurl
      pyopenssl
      pyusb
      requests
      tqdm
      unidecode
      urllib3
      watchdog
      zstandard
    ]
  );
in
stdenvNoCC.mkDerivation {
  pname = "nut";
  version = "0-unstable-2026-01-19";

  src = fetchFromGitHub {
    owner = "blawar";
    repo = "nut";
    rev = "b4b9377b5113d00675c40c28b1c218c10ac66838";
    hash = "sha256-7rChw9wngLLzjA87AoMw4WZPGG7DKZRS4qSHzAObNNw=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/nut $out/bin
    cp -r Fs Server nut cdn conf plugins public_html images nut.py \
      Certificate.cert ShopN.pem Ticket.tik keys_template.txt \
      $out/share/nut/
    ln -s ${python}/bin/python3 $out/bin/nut-python
    runHook postInstall
  '';

  passthru = { inherit python; };

  meta = {
    description = "Servidor de títulos de Nintendo Switch para o Tinfoil";
    homepage = "https://github.com/blawar/nut";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
