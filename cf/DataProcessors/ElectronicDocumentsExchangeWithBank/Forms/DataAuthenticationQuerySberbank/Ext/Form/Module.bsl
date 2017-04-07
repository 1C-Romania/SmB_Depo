
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.NumberContainer > 0 Then
		UserAccount = "PIN" + Parameters.NumberContainer;
		Items.UserAccount.Enabled = False;
		CurrentItem = Items.PinCode;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(ElectronicDocumentsServiceClient.ValueFromCache("NumberContainer")) Then
		SessionCompleted = False;
		ElectronicDocumentsServiceClient.CompleteSessionOnToken(SessionCompleted);
		If Not SessionCompleted Then
			Cancel = True;
		EndIf;
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure OK(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	NumberContainer = Number(Mid(UserAccount, 4, 1));
	
	ElectronicDocumentsServiceClient.CasheSberbankParameter("NumberContainer", NumberContainer);
	ElectronicDocumentsServiceClient.CasheSberbankParameter("PinCode", PinCode);
	ElectronicDocumentsServiceClient.CasheSberbankParameter("CurrentEDAgreement", Parameters.EDAgreement);

	Close(Parameters.EDAgreement);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close(Undefined);
	
EndProcedure
