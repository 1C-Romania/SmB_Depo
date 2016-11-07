////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABLE FIELD EVENT HANDLERS LIST

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy Then
		Return;
	EndIf;
	
	Cancel = True;
	
	If EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughBankWebSource") Then
		OpenForm("Catalog.EDUsageAgreements.Form.ItemFormBank",
					 ,
					 ,
					 UUID);
	Else
		OpenForm("Catalog.EDUsageAgreements.ObjectForm",
					 ,
					 ,
					 UUID);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("WindowOpeningMode") Then
		ThisObject.WindowOpeningMode = Parameters.WindowOpeningMode;
	EndIf;
	
	Items.Counterparty.Visible = (NOT ThisObject.Parameters.Filter = Undefined
									 AND ThisObject.Parameters.Filter.Property("EDExchangeMethod", EDExchangeMethod))
									AND EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource;
	
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
