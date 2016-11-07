
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
