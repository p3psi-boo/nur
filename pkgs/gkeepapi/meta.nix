{
  # 指定此包需要从 python311Packages 调用
  extraArgs = final: {
    buildPythonPackage = final.python311Packages.buildPythonPackage;
    flit-core = final.python311Packages.flit-core;
    gpsoauth = final.python311Packages.gpsoauth;
    future = final.python311Packages.future;
  };
}
