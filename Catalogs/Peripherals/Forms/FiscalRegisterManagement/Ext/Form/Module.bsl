
#Region FormCommandsHandlers

&AtClient
Procedure ReportPrintingWithoutBlankingExecute()
	
	Context = New Structure("Action", "PrintXReport");
	NotifyDescription = New NotifyDescription("ReportPrintEnd", ThisObject, Context);
	EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "FiscalRegister",
		NStr("en='Select the fiscal register'"), NStr("en='Fiscal register is not connected.'"));
	
EndProcedure

&AtClient
Procedure ReportPrintingWithBlankingExecute()
	
	Context = New Structure("Action", "PrintZReport");
	NotifyDescription = New NotifyDescription("ReportPrintEnd", ThisObject, Context);
	EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "FiscalRegister",
		NStr("en='Select the fiscal register'"), NStr("en='Fiscal register is not connected.'"));
	
EndProcedure

&AtClient
Procedure ReportPrintEnd(DeviceIdentifier, Parameters) Export
	
	If Not Parameters.Property("Action") Then
		Return;
	EndIf;
	
	ErrorDescription = "";
	
	Result = EquipmentManagerClient.ConnectEquipmentByID(UUID, DeviceIdentifier, ErrorDescription);
	If Result Then
		InputParameters  = Undefined;
		Output_Parameters = Undefined;
		Result = EquipmentManagerClient.RunCommand(DeviceIdentifier, Parameters.Action, InputParameters, Output_Parameters);
		
		If Not Result Then
			MessageText = NStr("en = 'An error occurred while getting the report from fiscal register.
				|%ErrorDescription%
				|Report on fiscal register is not formed.'");
				MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
		EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
		
	Else
		MessageText = NStr("en = 'An error occurred when connecting the device.'") + Chars.LF + ErrorDescription;
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

#EndRegion