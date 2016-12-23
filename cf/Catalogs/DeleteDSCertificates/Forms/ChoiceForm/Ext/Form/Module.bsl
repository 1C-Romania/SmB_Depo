
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














