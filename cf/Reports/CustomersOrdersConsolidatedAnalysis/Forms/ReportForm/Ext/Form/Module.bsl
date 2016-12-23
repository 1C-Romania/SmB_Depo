
&AtServer
//Procedure - form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If IsBlankString(Parameters.FilterByShippingState) Or
		Items.FilterByShippingState.ChoiceList.FindByValue(Parameters.FilterByShippingState) = Undefined Then
			Report.FilterByShippingState = Items.FilterByShippingState.ChoiceList[0].Value;
	Else
		Report.FilterByShippingState = Items.FilterByShippingState.ChoiceList.FindByValue(Parameters.FilterByShippingState).Value;
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



















