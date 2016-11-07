
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ExceptionList = Undefined;
	If Parameters.Property("ExceptionList", ExceptionList)
		AND TypeOf(ExceptionList) = Type("Array") Then
		CommonUseClientServer.SetFilterDynamicListItem(List, "Ref",
			ExceptionList, DataCompositionComparisonType.NotInList, , True);
	EndIf;
	
	Company = Undefined;
	
	DescriptionCompanyCatalog = ElectronicDocumentsReUse.GetAppliedCatalogName("Companies");
	If Not ValueIsFilled(DescriptionCompanyCatalog) Then
		DescriptionCompanyCatalog = "Companies";
	EndIf;
	
	If Parameters.Property("Company", Company)
		AND TypeOf(Company) = Type("CatalogRef."+ DescriptionCompanyCatalog) Then
		
		CommonUseClientServer.SetFilterDynamicListItem(List, "Company",
			Company, DataCompositionComparisonType.Equal, , True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	NotifyChoice(ValueSelected);
	
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
