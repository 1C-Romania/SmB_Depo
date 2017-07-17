#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByCompany(FillingData)
	
	Company = FillingData;
	
EndProcedure // FillByFixedAssets()

#EndRegion

#Region EventsHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.Companies") Then
		FillByCompany(FillingData);
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler Posting(). Creates
// a document movement by accumulation registers and accounting register.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.FixedAssetsDepreciation.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectFixedAssets(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectMonthEndErrors(AdditionalProperties, RegisterRecords, Cancel);
	
	If AdditionalProperties.TableForRegisterRecords.TableMonthEndErrors.Count() > 0 Then
		MessageText = NStr("en='Warnings were generated during depreciation accrual. For more information, see the month ending report.';ru='При начислении амортизации были сформированы предупреждения! Подробнее см. в отчете о закрытии месяца.'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

#EndRegion

#EndIf