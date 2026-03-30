{
  generated,
  lib,
  python3Packages,
}:

let
  sourceInfo = generated.telegram-send;
  py = python3Packages;
in
py.buildPythonApplication {
  pname = "telegram-send";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  pyproject = true;

  build-system = [ py.hatchling ];

  dependencies = [
    py.platformdirs
    py.python-telegram-bot
  ];

  pythonRelaxDeps = [ "python-telegram-bot" ];

  doCheck = false;

  pythonImportsCheck = [ "telegram_send" ];

  meta = {
    description = "Send messages and files over Telegram from the command line";
    homepage = "https://github.com/rahiel/telegram-send";
    license = lib.licenses.gpl3Plus;
    mainProgram = "telegram-send";
  };
}
