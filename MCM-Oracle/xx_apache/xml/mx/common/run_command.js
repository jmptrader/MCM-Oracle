function runCmd(command, directory) {
    command = 'cmd /c cd /d ' + directory + ' & ' + command;
    var wsh = new ActiveXObject('WScript.Shell');
    wsh.Run(command);
}
