
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	BanksCatalogName = AppliedCatalogName("Banks");
	If Not ValueIsFilled(BanksCatalogName) Then
		BanksCatalogName = "RFBankClassifier";
	EndIf;
	
	DescriptionCounterpartiesCatalog = AppliedCatalogName("Counterparties");
	If Not ValueIsFilled(DescriptionCounterpartiesCatalog) Then
		DescriptionCounterpartiesCatalog = "Counterparties";
	EndIf;
	DescriptionCompanyCatalog = AppliedCatalogName("Companies");
	If Not ValueIsFilled(DescriptionCompanyCatalog) Then
		DescriptionCompanyCatalog = "Companies";
	EndIf;
	
	FormParameters = New Structure;
	If TypeOf(CommandParameter) = Type("CatalogRef." + DescriptionCounterpartiesCatalog) Then
		FormParameters.Insert("Counterparty", CommandParameter);
	ElsIf TypeOf(CommandParameter) = Type("CatalogRef." + DescriptionCompanyCatalog) Then
		FormParameters.Insert("Company", CommandParameter);
	ElsIf TypeOf(CommandParameter) = Type("CatalogRef." + BanksCatalogName) Then
		FormParameters.Insert("Bank", CommandParameter);
	ElsIf TypeOf(CommandParameter) = Type("CatalogRef.EDFProfileSettings") Then
		FormParameters.Insert("EDFProfileSettings", CommandParameter);
	EndIf;
	
	If InUseAdditionalAnalyticsCompanies() Then
		PartnersCatalogName = AppliedCatalogName("partners");
		If TypeOf(CommandParameter) = Type("CatalogRef." + PartnersCatalogName) Then
			FormParameters.Insert("Partner", CommandParameter);
		EndIf;
	EndIf;
	
	FormParameters.Insert("DoNotShowQuickFilters");
	
	OpenForm("Catalog.EDUsageAgreements.ListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

&AtServer
Function AppliedCatalogName(Description)
	
	Return ElectronicDocumentsReUse.GetAppliedCatalogName(Description);
	
EndFunction

&AtServer
Function InUseAdditionalAnalyticsCompanies()
	
	Return ElectronicDocumentsReUse.UseAdditionalAnalyticsOfCompaniesCatalogPartners();
	
EndFunction
