
// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If IsBlankString(Parameters.FilterByReceiptState) Or
		Items.FilterByReceiptState.ChoiceList.FindByValue(Parameters.FilterByReceiptState) = Undefined Then
			Report.FilterByReceiptState = Items.FilterByReceiptState.ChoiceList[0].Value;
	Else
		Report.FilterByReceiptState = Items.FilterByReceiptState.ChoiceList.FindByValue(Parameters.FilterByReceiptState).Value;
	EndIf;
	
	If IsBlankString(Parameters.FilterByPaymentState) Or
		Items.FilterByPaymentState.ChoiceList.FindByValue(Parameters.FilterByPaymentState) = Undefined Then
		Report.FilterByPaymentState = Items.FilterByPaymentState.ChoiceList[0].Value;
	Else
		Report.FilterByPaymentState = Items.FilterByPaymentState.ChoiceList.FindByValue(Parameters.FilterByPaymentState).Value;
	EndIf;
	
	Parameters.GenerateOnOpen = True;
	
EndProcedure

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, Settings);
EndProcedure

















