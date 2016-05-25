
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Template = ExchangePlans.ExchangeSmallBusinessAccounting20.GetTemplate("DetailedInformationAboutExchange");
	
	HTMLDocumentField = Template.GetText();
	
	Title = NStr("en = 'Information about data synchronization with ""1C: Accounting 8, ed. 2.0""'");
	
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
