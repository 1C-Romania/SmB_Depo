
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
#If WebClient Then
	ShowMessageBox(, NStr("en = 'In the web client the proxy server parameters must be specified in the browser settings.'"));
	Return;
#EndIf
	
	OpenForm("CommonForm.ProxyServerParameters", New Structure("ProxySettingAtClient", True));
	
EndProcedure

#EndRegion
