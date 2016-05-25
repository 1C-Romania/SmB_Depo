
#Region FormEventsHandlers

&AtClient
Procedure OnOpen(Cancel)
	ItemCount = 0;
	If FileOperationsServiceClient.InitializeComponent() Then
		DeviceArray = FileOperationsServiceClient.GetDevices();
		For Each String IN DeviceArray Do
			ItemCount = ItemCount + 1;
			Items.DeviceName.ChoiceList.Add(String);
		EndDo;
	EndIf;
	If ItemCount = 0 Then
		Cancel = True;
		ShowMessageBox(, NStr("en = 'The scanner is not installed. Contact your application administrator.'"));
	Else
		Items.DeviceName.ListChoiceMode = True;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ChooseScanner(Command)
	SystemInfo = New SystemInfo();
	CommonUseServerCall.CommonSettingsStorageSave(
		"ScanningSettings/DeviceName",
		SystemInfo.ClientID,
		DeviceName);
	RefreshReusableValues();
	Close(DeviceName);
EndProcedure

#EndRegion


// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
