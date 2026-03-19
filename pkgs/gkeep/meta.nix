{
  # 指定此包需要从 python311Packages 调用
  extraArgs = final: {
    buildPythonApplication = final.python311Packages.buildPythonApplication;
    click = final.python311Packages.click;
  };
}
