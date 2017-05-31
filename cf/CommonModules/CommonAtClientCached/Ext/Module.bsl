Function IsWebClientMacOS() Export
	
#If Not WebClient Then
	Return False;
#EndIf
	
	SystemInfo = New SystemInfo;
	If Find(SystemInfo.UserAgentInformation, "Macintosh") <> 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function StartupClientParameters() Export
#If WebClient Then
	IsWebClient = True;
#Else
	IsWebClient = False;
#EndIf
	IsWebClientMacOS = IsWebClientMacOS();
	SystemInfo = New SystemInfo;
	IsWindowsClient = SystemInfo.PlatformType = PlatformType.Windows_x86
	              Or SystemInfo.PlatformType = PlatformType.Windows_x86_64;
	IsLinuxClient = SystemInfo.PlatformType = PlatformType.Linux_x86
	              Or SystemInfo.PlatformType = PlatformType.Linux_x86_64;
	IsMacOSClient = SystemInfo.PlatformType = PlatformType.MacOS_x86
				  Or SystemInfo.PlatformType = PlatformType.MacOS_x86_64;

	Parameters = New Structure;
	
	Parameters.Insert("LaunchParameter",	   LaunchParameter);
	Parameters.Insert("InfoBaseConnectionString", InfoBaseConnectionString());
	Parameters.Insert("IsWebClient",         IsWebClient);
	Parameters.Insert("IsWebClientMacOS",    IsWebClientMacOS);
	Parameters.Insert("IsLinuxClient",       IsLinuxClient);
	Parameters.Insert("IsMacOSClient",       IsMacOSClient);
	Parameters.Insert("IsWindowsClient",     IsWindowsClient);
	Parameters.Insert("HideDesktopAtSystemStartup", False);
	Parameters.Insert("TempAdressObjects", New Map);
	#If WebClient Then
		Parameters.Insert("mComputerName", "");
	#Else
		Parameters.Insert("mComputerName", Upper(ComputerName()));
	#EndIf
	Parameters.Insert("TradeWareForms", New Map);
	Parameters.Insert("TradeWare", New Map);
	
	ClientParameters = CommonAtServer.StartupClientParameters(Parameters);
	
	Return ClientParameters;
EndFunction