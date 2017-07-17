
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
#If WebClient Then
	ShowMessageBox(, NStr("en='Set proxy server parameters of web client in browser settings.';ru='В веб-клиенте параметры прокси-сервера необходимо задавать в настройках браузера.'"));
	Return;
#EndIf
	
	OpenForm("CommonForm.ProxyServerParameters", New Structure("ProxySettingAtClient", True));
	
EndProcedure

#EndRegion
