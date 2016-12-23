
&AtServer
//Procedure - form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter")
		AND Parameters.Filter.Property("Account") Then
		
		Items.FolderFilterInteractive.Enabled = False;
		
	EndIf;
	
	Report.FilterByPaymentState = Items.FilterByPaymentState.ChoiceList[0].Value;
	Parameters.GenerateOnOpen = True;
	
EndProcedure

&AtClient
//Procedure event handler OnChange attribute FilterByPaymentsState.
//
&AtClient
Procedure FilterByPaymentStateOnChange(Item)
	
	ComposeResult();
	
EndProcedure

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, Settings);
EndProcedure














