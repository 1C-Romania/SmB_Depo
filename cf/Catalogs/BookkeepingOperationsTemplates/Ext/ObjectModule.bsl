
Procedure BeforeWrite(Cancel)
	
	If IsFolder Then
		Return;
	EndIf;	
	
	If Ref.WorkMode Then // Check templates that are already written as work.
		
		If Not WorkMode Then // try to turn back to test mode
			Privileged.IsCatalogInPostedDocuments(New Structure, , Ref, Cancel);
		Else // just forbid to change template
			Alerts.AddAlert(NStr("en = 'You cann''t change template in work mode.'; pl = 'Nie można zmieniać schematu w trybie roboczym.'"), Enums.AlertType.Error, Cancel, ThisObject);
		EndIf;
		
	EndIf;
	
	#If NOT ThickClientOrdinaryApplication Then
		UpdateTypeFromStringInternal();

		Filter = New ValueStorage(FilterAsXML);
	#EndIf
EndProcedure


// Fills Bookkeeping document. If bookkeeping document should be filled on document ref, then also fills it.
// DocumentRef - This value should be filled if bookkeeping operation should be filled based on document
// BookkeepingDocumentRef - If empty then new document will be created, otherwise will be overwritted
Function FillBookkeepingDocument(DocumentRef, BookkeepingDocumentObject) Export
	
	BookkeepingTemplateObject = GetBookkeepingTemplateObject();
	CalculatedParameters = CalculateParameters(DocumentRef,BookkeepingDocumentObject);
	FillBookkeepingDocumentRecords(DocumentRef, BookkeepingDocumentObject, BookkeepingTemplateObject,CalculatedParameters);
	FillBookkeepingDocumentSalesVATRecords(DocumentRef, BookkeepingDocumentObject, BookkeepingTemplateObject,CalculatedParameters);
	FillBookkeepingDocumentPurchaseVATRecords(DocumentRef, BookkeepingDocumentObject, BookkeepingTemplateObject,CalculatedParameters);
	
EndFunction	

Function FillBookkeepingDocumentRecords(DocumentRef, BookkeepingDocumentObject,BookkeepingTemplateObject = Undefined,CalculatedParameters = Undefined) Export
		
	If BookkeepingTemplateObject = Undefined Then
		BookkeepingTemplateObject = GetBookkeepingTemplateObject();
	EndIf;	
	
	If CalculatedParameters = Undefined Then
		CalculatedParameters = CalculateParameters(DocumentRef,BookkeepingDocumentObject);
	EndIf;	
	
	If TypeOf(BookkeepingTemplateObject) = Type("CatalogObject.BookkeepingOperationsTemplates") Then
		
		FillRecordsTable(DocumentRef,BookkeepingDocumentObject.Company,BookkeepingDocumentObject.Date,BookkeepingDocumentObject.Records,Records,CalculatedParameters,True, GroupRecords,DontGenerateZeroRecords,True);
		
	Else
		
		BookkeepingTemplateObject.FillBookkeepingDocumentRecords(DocumentRef,BookkeepingDocumentObject.Company,BookkeepingDocumentObject.Date, BookkeepingDocumentObject);
		
	EndIf;		
	
EndFunction	

Function FillBookkeepingDocumentSalesVATRecords(DocumentRef, BookkeepingDocumentObject,BookkeepingTemplateObject = Undefined,CalculatedParameters = Undefined) Export
		
	If BookkeepingTemplateObject = Undefined Then
		BookkeepingTemplateObject = GetBookkeepingTemplateObject();
	EndIf;	
	
	If CalculatedParameters = Undefined Then
		CalculatedParameters = CalculateParameters(DocumentRef,BookkeepingDocumentObject);
	EndIf;	
	
	If TypeOf(BookkeepingTemplateObject) = Type("CatalogObject.BookkeepingOperationsTemplates") Then
		
		FillRecordsTable(DocumentRef,BookkeepingDocumentObject.Company,BookkeepingDocumentObject.Date,BookkeepingDocumentObject.SalesVATRecords,SalesVATRecords,CalculatedParameters);
	Else
		
		BookkeepingTemplateObject.FillBookkeepingDocumentSalesVATRecords(DocumentRef,BookkeepingDocumentObject.Company,BookkeepingDocumentObject.Date, BookkeepingDocumentObject);
		
	EndIf;	
	
EndFunction	

Function FillBookkeepingDocumentPurchaseVATRecords(DocumentRef, BookkeepingDocumentObject,BookkeepingTemplateObject = Undefined,CalculatedParameters = Undefined) Export
		
	If BookkeepingTemplateObject = Undefined Then
		BookkeepingTemplateObject = GetBookkeepingTemplateObject();
	EndIf;	
	
	If CalculatedParameters = Undefined Then
		CalculatedParameters = CalculateParameters(DocumentRef,BookkeepingDocumentObject);
	EndIf;	
	
	If TypeOf(BookkeepingTemplateObject) = Type("CatalogObject.BookkeepingOperationsTemplates") Then
		
		FillRecordsTable(DocumentRef,BookkeepingDocumentObject.Company,BookkeepingDocumentObject.Date,BookkeepingDocumentObject.PurchaseVATRecords,PurchaseVATRecords,CalculatedParameters);
	Else
		
		BookkeepingTemplateObject.FillBookkeepingDocumentPurchaseVATRecords(DocumentRef,BookkeepingDocumentObject.Company,BookkeepingDocumentObject.Date, BookkeepingDocumentObject);
		
	EndIf;	
	
EndFunction	

Function GetBookkeepingTemplateObject() Export
	
	If Type = Enums.BookkeepingOperationTemplateTypes.AsDataProcessor Then
		
		If InternalDataProcessor Then
			
			DataProcessor = DataProcessors[FileName].Create();
			
		Else
			
			//BinaryData = OperationTemplateAsDataProcessor.Get();
			//TempFileName = GetTempFileName("epf");
			//BinaryData.Write(TempFileName);
			//DataProcessor = ExternalDataProcessors.Create(TempFileName);
			
		EndIf;
		
		Return DataProcessor;
		
	ElsIf Type = Enums.BookkeepingOperationTemplateTypes.Normal Then	
		
		Return ThisObject;
		
	EndIf;

EndFunction	

Function CalculateParameters(DocumentRef,DocumentObject) Export
	
	// Structure will be filled by parameters values 
	ParametersValues = New ValueTable();
	ParametersValues.Columns.Add("LineNumber");
	ParametersValues.Columns.Add("Name");
	ParametersValues.Columns.Add("Value");
	
	// Structure will be filled by all parameters for which should be got value
	ParametersToGetValues = New Structure();
	// Difference between ParametersToGetValues and ParametersValues gives us parameters which was not filled	
	
	// Prepearing for system data parameters
	SystemDataDataCompositionSettingsComposer = New DataCompositionSettingsComposer;
	TemplateComposer = New DataCompositionTemplateComposer;	
	
	SystemDataCompositionDataSchema = GetTemplate("SystemData");
	SystemDataDataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SystemDataCompositionDataSchema));
	NewGroup = SystemDataDataCompositionSettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	
	// Set parameters for SliceList of system data. Company and period are got from DocumentRef
	TemplateReports.SetParameter(SystemDataDataCompositionSettingsComposer,"Company",DocumentObject.Company);
	TemplateReports.SetParameter(SystemDataDataCompositionSettingsComposer,"Period",DocumentObject.Date);
	
	// Preparing for linked parameters
	LinkedParametersTable = Parameters.UnloadColumns("TableName, TableKind");
	LinkedParametersTable.Columns.Add("FieldsArray");
	
	For Each Parameter In Parameters Do
		
		ParametersToGetValues.Insert(Parameter.Name,Parameter.Presentation);
		
		If Parameter.ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.LinkedToDocumentBase Then
			
			FoundRows = LinkedParametersTable.FindRows(New Structure("TableName, TableKind",Parameter.TableName,Parameter.TableKind));
			If FoundRows.Count()=0 Then
				
				NewRow = LinkedParametersTable.Add();
				NewRow.TableKind = Parameter.TableKind;
				NewRow.TableName = Parameter.TableName;
				NewRow.FieldsArray = New Array();	
			Else	
				NewRow = FoundRows[0];
			EndIf;	
			
			NewRow.FieldsArray.Add(Parameter.ParameterFormula);
			
		ElsIf Parameter.ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.SystemData Then
			
			// Add field to data composition selection
			NewField = NewGroup.Selection.Items.Add(Type("DataCompositionSelectedField"));
			NewField.Field = New DataCompositionField(Parameter.ParameterFormula);
			NewField.Use = True;
			
		ElsIf Parameter.ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.NotLinked Then	
			
			NewRow = ParametersValues.Add();
			NewRow.LineNumber = 0;
			NewRow.Name = Parameter.Name;
			NewRow.Value = Parameter.Value;
			if DocumentRef = Undefined Then
				// Overwrite exiting value by value from RequestedParameters
				FoundRow = TablesProcessingAtClientAtServer.FindTabularPartRow(DocumentObject.RequestedParameters,New Structure("Name",Parameter.Name));
				If FoundRow<> Undefined Then
					NewRow.Value = FoundRow.Value;
				EndIf;	
				
			EndIf;
			
		EndIf;	
		
	EndDo;	
	
	QueryQueue = New ValueTable();
	QueryQueue.Columns.Add("ParameterKind");
	QueryQueue.Columns.Add("TableName");
	QueryQueue.Columns.Add("TableKind");
	
	// General query
	DataQuery = New Query();
	
	// System Data parameters processing
	CompositionTemplate = TemplateComposer.Execute(SystemDataCompositionDataSchema, SystemDataDataCompositionSettingsComposer.Settings,,,Type("DataCompositionValueCollectionTemplateGenerator"));	
	
	If CompositionTemplate.DataSets.Count()>0 Then
		
		For Each DataSet In CompositionTemplate.DataSets.SystemData.Items Do
			
			If NOT IsBlankString(DataSet.Query) 
				AND DataSet.Name <> "ExchangeRateDifferences"
				AND DataSet.Name <> "GeneralRounding" Then

				DataQuery.Text = DataQuery.Text + StrReplace(DataSet.Query,"&","&SD") + "; ";
				QueryQueueRow = QueryQueue.Add();
				QueryQueueRow.ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.SystemData;
			EndIf;	
			
		EndDo;	
		
		For Each Parameter In CompositionTemplate.ParameterValues Do
			DataQuery.SetParameter("SD"+Parameter.Name,Parameter.Value);
		EndDo;	
		
	EndIf;
	
	// Linked parameters processing
	LP = 0;
	For Each LinkedParametersTableRow In LinkedParametersTable Do
		
		DCS = New DataCompositionSchema;
		
		DataCompositionSettingsComposer = ApplyDocumentBaseTableChange(LinkedParametersTableRow.TableName,LinkedParametersTableRow.TableKind,DCS);
		If LinkedParametersTableRow.TableKind <> Enums.BookkeepingOperationTemplateTableKind.DocumentRecords 
			AND LinkedParametersTableRow.TableKind <> Enums.BookkeepingOperationTemplateTableKind.TabularSection Then
			TemplateReports.AddFilter(DataCompositionSettingsComposer,"Recorder",DocumentRef);
		Else
			TemplateReports.AddFilter(DataCompositionSettingsComposer,"Ref",DocumentRef);
		EndIf;
		NewGroup = DataCompositionSettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
		For Each FieldFormula In LinkedParametersTableRow.FieldsArray Do
				
			NewField = NewGroup.Selection.Items.Add(Type("DataCompositionSelectedField"));
			NewField.Field = New DataCompositionField(FieldFormula);
			NewField.Use = True;
			
		EndDo;	
		
		TemplateReports.SetParameter(DataCompositionSettingsComposer,"Period",DocumentObject.Date);	
		CompositionTemplate = TemplateComposer.Execute(DCS,DataCompositionSettingsComposer.Settings,,,Type("DataCompositionValueCollectionTemplateGenerator"));
		
		DataQuery.Text = DataQuery.Text + StrReplace(CompositionTemplate.DataSets.DataSet1.Query,"&","&LP"+LP) + "; ";
		
		QueryQueueRow = QueryQueue.Add();
		QueryQueueRow.ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.LinkedToDocumentBase;
		QueryQueueRow.TableKind = LinkedParametersTableRow.TableKind;
		QueryQueueRow.TableName = LinkedParametersTableRow.TableName;
		
		For Each Parameter In CompositionTemplate.ParameterValues Do
			DataQuery.SetParameter("LP"+LP+Parameter.Name,Parameter.Value);
		EndDo;	
		
		LP = LP+1
		
	EndDo;	
	
	If NOT IsBlankString(DataQuery.Text) Then
		
		QueryResultsArray = DataQuery.ExecuteBatch();
		IndexInQueue = 0;
		For Each QueryResultItem In QueryResultsArray Do
			
			Selection = QueryResultItem.Choose();
			LineNumber = 0;
			While Selection.Next() Do
				
				For Each Column In QueryResultItem.Columns Do
					
					If QueryQueue[IndexInQueue].ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.SystemData Then
						FoundRows = Parameters.FindRows(New Structure("FieldName, ParameterKind",Column.Name,QueryQueue[IndexInQueue].ParameterKind));
					Else
						FoundRows = Parameters.FindRows(New Structure("FieldName, ParameterKind, TableName, TableKind",Column.Name,QueryQueue[IndexInQueue].ParameterKind,QueryQueue[IndexInQueue].TableName,QueryQueue[IndexInQueue].TableKind));
					EndIf;	
					
					If FoundRows.Count()>0 Then
						
						For Each FoundRow In FoundRows Do
							NewRow = ParametersValues.Add();
							NewRow.LineNumber = LineNumber;
							NewRow.Name = FoundRow.Name;
							NewRow.Value = Selection[Column.Name];
						EndDo;
						
					EndIf;	
					
				EndDo;	
				
				LineNumber = LineNumber + 1;
				
			EndDo;	
			
			IndexInQueue = IndexInQueue + 1;
			
		EndDo;	
		
	EndIf;
	
	Return ParametersValues;
	
EndFunction	

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// GroupAccountingRecords and CalculateExchangeRateDifferences flag only for records for accounting register
// otherwise will be exception raised
Function FillRecordsTable(DocumentRef,DocumentCompany,DocumentPeriod,BookkeepingDocumentObjectRecords,SourceRecords,CalculatedParameters,CalculateExchangeRateDifferences = False,GroupAccountingRecords = False,CurrentDontGenerateZeroRecords = False,BookkeepingRecords = False)
	
	If TypeOf(SourceRecords) = Type("CatalogTabularSection.BookkeepingOperationsTemplates.Records") Then
		BookkeepingRecords = True;
	EndIf;	
	
	ManualRecords = BookkeepingDocumentObjectRecords.Unload(New Structure("Type",Enums.BookkeepingOperationRecordTypes.Manual));
	BookkeepingDocumentObjectRecords.Clear();
	
	TableMaxCounterMap = New Map();
	
	GroupedRecords = SourceRecords.Unload(,"TableKind, TableName");
	
	Query = New Query();
	
	For Each GroupedRecord In GroupedRecords Do
		
		If GroupedRecord.TableKind = Enums.BookkeepingOperationTemplateTableKind.DocumentRecords
			OR GroupedRecord.TableKind = Enums.BookkeepingOperationTemplateTableKind.EmptyRef() Then
			Continue;
		ElsIf GroupedRecord.TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection Then
			TableMaxCounterMap.Insert(CommonAtServer.GetEnumNameByValue(GroupedRecord.TableKind) + GroupedRecord.TableName,DocumentRef[GroupedRecord.TableName].Count());
		Else
			If GroupedRecord.TableKind = Enums.BookkeepingOperationTemplateTableKind.AccumulationRegister Then
				MetadatObjectName = "AccumulationRegister";
			ElsIf GroupedRecord.TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterPeriodic
				OR GroupedRecord.TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterNonperiodic Then	
				MetadatObjectName = "InformationRegister";
			EndIf;
			Query.Text = Query.Text + "SELECT ALLOWED
			|	COUNT(DISTINCT Register.LineNumber) AS Count,
			|	"""+ CommonAtServer.GetEnumNameByValue(GroupedRecord.TableKind) + GroupedRecord.TableName +""" AS MapName 
			|FROM
			| " + MetadatObjectName+"." + GroupedRecord.TableName+" AS Register
			|WHERE
			|	Register.Recorder = &Recorder; ";
		EndIf;	
		
	EndDo;	
	
	If NOT IsBlankString(Query.Text) Then
		
		Query.SetParameter("Recorder",DocumentRef);
		
		QueryResultArray = Query.ExecuteBatch();
		
		For Each QueryResultItem In QueryResultArray Do
			
			Selection = QueryResultItem.Choose();
			While Selection.Next() Do
				TableMaxCounterMap.Insert(Selection.MapName,Selection.Count);
			EndDo;	
			
		EndDo;	
		
	EndIf;	
	
	// ExchangeRate differences
	AmountDr = 0;
	AmountCr = 0;
	
	CurrencyAmountDr = 0;
	CurrencyAmountCr = 0;
	
	BookkeepingDocumentObjectRecordsVT = New Array;
	
	For Each Record In SourceRecords Do
		
		RecordIndex = SourceRecords.IndexOf(Record)+1;
		BookkeepingDocumentObjectRecordsVT.Add(New Array);
		CurrentBookkeepingDocumentObjectRecordsVT = BookkeepingDocumentObjectRecordsVT.Get(RecordIndex-1);
		
		If Record.TableKind = Enums.BookkeepingOperationTemplateTableKind.DocumentRecords Then
			MaxCounter = 1;
		Else
			FoundMapItem = TableMaxCounterMap.Get(CommonAtServer.GetEnumNameByValue(Record.TableKind) + Record.TableName);
			If FoundMapItem = Undefined Then
				MaxCounter = 1;
			Else
				MaxCounter = FoundMapItem;
			EndIf;	
		EndIf;	
		
		For Counter = 1 To MaxCounter Do
			
			If IsBlankString(Record.Formulas) Then
				ParametersMap = New Map();
			Else	
				ParametersMap = ValueFromStringInternal(Record.Formulas);
			EndIf;	
			
			ConditionFormula = ParametersMap.Get("Condition");
			If ConditionFormula <> Undefined 
				AND NOT IsBlankString(ConditionFormula.Value) Then
				
				ConditionValue = CalculateFormula(ConditionFormula,Undefined,BookkeepingDocumentObjectRecords,BookkeepingDocumentObjectRecordsVT,CalculatedParameters,Counter);
				If ConditionValue <> True Then
					Continue;
				EndIf;	
				
			EndIf;	
						
			NewRecord = BookkeepingDocumentObjectRecords.Add();
			CurrentBookkeepingDocumentObjectRecordsVT.Add(NewRecord);
			ExcludeList = "";
			
			For Each KeyAndValue In ParametersMap Do
				If KeyAndValue.Key = "Condition" Then
					Continue;
				EndIf;	
				If KeyAndValue.Value.Value = "" Then
					Continue;
				EndIf;	
				NewRecord[KeyAndValue.Key] = CalculateFormula(KeyAndValue.Value,NewRecord,BookkeepingDocumentObjectRecords,BookkeepingDocumentObjectRecordsVT,CalculatedParameters,Counter);
			EndDo;	
			
			If CalculateExchangeRateDifferences AND Record.UseInExchangeRateDifferenceCalculation Then
				
				If NewRecord.AmountDr<>0 Then
					AmountDr = AmountDr + NewRecord.AmountDr;
					CurrencyAmountDr = CurrencyAmountDr + NewRecord.CurrencyAmount;
				Else
					AmountCr = AmountCr + NewRecord.AmountCr;
					CurrencyAmountCr = CurrencyAmountCr + NewRecord.CurrencyAmount;
				EndIf;	
				
			EndIf;	
						
			If CurrentDontGenerateZeroRecords 
				AND NewRecord.AmountDr=0 AND NewRecord.AmountCr=0 Then
				BookkeepingDocumentObjectRecords.Delete(NewRecord);
				CurrentBookkeepingDocumentObjectRecordsVT.Delete(CurrentBookkeepingDocumentObjectRecordsVT.Count()-1);
			EndIf;	
			
		EndDo;	
		
	EndDo;	
	
	If CalculateExchangeRateDifferences AND BookkeepingRecords AND CurrencyAmountDr-CurrencyAmountCr=0 Then
		ExchangeRateDifference = AmountDr-AmountCr;
		If ExchangeRateDifference <> 0 Then
			DistributeDrCrDifferences(ExchangeRateDifference,BookkeepingDocumentObjectRecords,BookkeepingDocumentObjectRecordsVT,CalculatedParameters,DocumentCompany,DocumentPeriod,Enums.BookkeepingOperationBalanceDifferenceTypes.ExchangeRateDifference);
		EndIf;	
	EndIf;
		
	If BookkeepingRecords AND AlgorithmType = Enums.BookkeepingOperationTemplateAlgorithmTypes.BookkeepingRecordsBeforeGrouping Then
		ExecuteAlgorithmInScope(AlgorithmText,BookkeepingDocumentObjectRecords,BookkeepingDocumentObjectRecordsVT,CalculatedParameters);
	EndIf;	
	
	If GroupAccountingRecords Then
		
		BufTable = BookkeepingDocumentObjectRecords.Unload();
		BufTable.Columns.Add("GroupCrDr");
		For Each Row In BufTable Do
			
			If Row.AmountDr<>0 AND Row.AmountCr<>0 Then 
				Row.GroupCrDr = 2;
			ElsIf Row.AmountDr=0 AND Row.AmountCr=0 Then
				Row.GroupCrDr = -2;
			ElsIf Row.AmountDr<>0 AND Row.AmountCr=0 Then
				Row.GroupCrDr = 1;
			ElsIf Row.AmountDr=0 AND Row.AmountCr<>0 Then
				Row.GroupCrDr = -1;
			EndIf;	
			
		EndDo;	
		
		BufTable.GroupBy("Account, ExtDimension1, ExtDimension2, ExtDimension3, Currency, Description,GroupCrDr","Quantity, CurrencyAmount, AmountDr, AmountCr");
		BufTable.Columns.Delete("GroupCrDr");
		
		i = 0;
		While i<BufTable.Count() do
			
			BufTableRow = BufTable.Get(i);
			
			If CurrentDontGenerateZeroRecords AND BufTableRow.AmountDr = 0 AND BufTableRow.AmountCr = 0 Then
				BufTable.Delete(BufTableRow);
			Else
				If BufTableRow.AmountDr<0 AND BufTableRow.CurrencyAmount<=0 Then
					BufTableRow.AmountCr = -BufTableRow.AmountDr;
					BufTableRow.AmountDr = 0;
					If BufTableRow.CurrencyAmount<0 Then
						BufTableRow.CurrencyAmount = -BufTableRow.CurrencyAmount;
					EndIf;	
				EndIf;	
				If BufTableRow.AmountCr<0 AND BufTableRow.CurrencyAmount<=0 Then
					BufTableRow.AmountDr = -BufTableRow.AmountCr;
					BufTableRow.AmountCr = 0;
					If BufTableRow.CurrencyAmount<0 Then
						BufTableRow.CurrencyAmount = -BufTableRow.CurrencyAmount;
					EndIf;	
				EndIf;	
				i=i+1;
			EndIf;	
			
		EndDo;	
		
		BookkeepingDocumentObjectRecords.Load(BufTable);
		
	EndIf;	
		
	If BookkeepingRecords AND AlgorithmType = Enums.BookkeepingOperationTemplateAlgorithmTypes.BookkeepingRecordsAfterGrouping Then
		ExecuteAlgorithmInScope(AlgorithmText,BookkeepingDocumentObjectRecords,Undefined,CalculatedParameters);
	EndIf;	
	
	AutoDifferenceCompensationAmountDr = 0;
	AutoDifferenceCompensationAmountCr = 0;
	
	For Each BookkeepingDocumentObjectRecordsRecord In BookkeepingDocumentObjectRecords Do
		BookkeepingDocumentObjectRecordsRecord.Type = Enums.BookkeepingOperationRecordTypes.Auto;
		If AutoDifferenceCompensation AND BookkeepingRecords Then
			AutoDifferenceCompensationAmountDr = AutoDifferenceCompensationAmountDr + BookkeepingDocumentObjectRecordsRecord.AmountDr;
			AutoDifferenceCompensationAmountCr = AutoDifferenceCompensationAmountCr + BookkeepingDocumentObjectRecordsRecord.AmountCr;
		EndIf;	
	EndDo;	
	
	If AutoDifferenceCompensationAmount AND BookkeepingRecords Then 
		ExchangeRateDifferenceCompensation = AutoDifferenceCompensationAmountDr - AutoDifferenceCompensationAmountCr;
		If abs(ExchangeRateDifferenceCompensation)<=AutoDifferenceCompensationAmount Then
			DistributeDrCrDifferences(ExchangeRateDifferenceCompensation,BookkeepingDocumentObjectRecords,BookkeepingDocumentObjectRecordsVT,CalculatedParameters,DocumentCompany,DocumentPeriod,Enums.BookkeepingOperationBalanceDifferenceTypes.GeneralRoundingDifference);
	    EndIf;
	EndIf;	
	
	For Each ManualRecord In ManualRecords Do
		MewManualRow = BookkeepingDocumentObjectRecords.Add();
		FillPropertyValues(MewManualRow,ManualRecord);
	EndDo;	
	
EndFunction	

Procedure DistributeDrCrDifferences(ExchangeRateDifference,BookkeepingDocumentObjectRecords,BookkeepingDocumentObjectRecordsVT,CalculatedParameters,DocumentCompany,DocumentPeriod,DifferenceType)
	
	If ExchangeRateDifference = 0 Then
		Return;
	Endif;	
	
	If ExchangeRateDifference<0 Then
		Sign = Enums.ExchangeRateDifferenceSign.Negative;
	Else
		Sign = Enums.ExchangeRateDifferenceSign.Positive;
	EndIf;	
	
	ExchangeRateDifferencesData = Undefined;
	For Each ExchangeRateDifferencesRow In ExchangeRateDifferences Do
		
		If ExchangeRateDifferencesRow.Type = DifferenceType Then
			ExchangeRateDifferencesData = ExchangeRateDifferencesRow;
		EndIf;	                           
		
	EndDo;	
	
	If ExchangeRateDifferencesData = Undefined Then
		// no policy defined in schema
		Return;
	EndIf;	
	
	CarriedOut = ExchangeRateDifferencesData.ExchangeRateDifferencesCarriedOut;
	
	If IsBlankString(ExchangeRateDifferencesData.Formulas) Then
		ParametersMap = New Map();
	Else	
		ParametersMap = ValueFromStringInternal(ExchangeRateDifferencesData.Formulas);
	EndIf;	
	
	GroupKindFormula = ParametersMap.Get("ExchangeRateDifferencesGroup");
	GroupKind = CalculateFormula(GroupKindFormula,Undefined,BookkeepingDocumentObjectRecords,BookkeepingDocumentObjectRecordsVT,CalculatedParameters,0);
	
	SystemDataDataCompositionSettingsComposer = New DataCompositionSettingsComposer;
	TemplateComposer = New DataCompositionTemplateComposer;	
	
	SystemDataCompositionDataSchema = GetTemplate("SystemData");
	SystemDataDataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SystemDataCompositionDataSchema));
	NewGroup = SystemDataDataCompositionSettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	// Structure will be filled by all parameters for which should be got value
	ParametersToGetValues = New Structure();
	
	For Each Parameter In Parameters Do
		
		If Parameter.ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.SystemData
			AND CalculatedParameters.FindRows(New Structure("Name",Parameter.Name)).Count()=0 Then
			
			ParametersToGetValues.Insert(Parameter.Name,Parameter.Presentation);
			
			// Add field to data composition selection
			NewField = NewGroup.Selection.Items.Add(Type("DataCompositionSelectedField"));
			NewField.Field = New DataCompositionField(Parameter.ParameterFormula);
			NewField.Use = True;
			
		EndIf;	
		
	EndDo;	
	
	// Set parameters for SliceList of system data. Company and period are got from DocumentRef
	TemplateReports.SetParameter(SystemDataDataCompositionSettingsComposer,"Company",DocumentCompany);
	TemplateReports.SetParameter(SystemDataDataCompositionSettingsComposer,"Period",DocumentPeriod);
	TemplateReports.SetParameter(SystemDataDataCompositionSettingsComposer,"Sign",Sign);
	TemplateReports.SetParameter(SystemDataDataCompositionSettingsComposer,"GroupKind",GroupKind);
	TemplateReports.SetParameter(SystemDataDataCompositionSettingsComposer,"CarriedOut",CarriedOut);		
	
	// System Data parameters processing
	CompositionTemplate = TemplateComposer.Execute(SystemDataCompositionDataSchema, SystemDataDataCompositionSettingsComposer.Settings,,,Type("DataCompositionValueCollectionTemplateGenerator"));	
	
	DataQuery = New Query();
	
	If CompositionTemplate.DataSets.Count()>0 Then
		
		If DifferenceType = Enums.BookkeepingOperationBalanceDifferenceTypes.ExchangeRateDifference Then
			DataQuery.Text = CompositionTemplate.DataSets.SystemData.Items["ExchangeRateDifferences"].Query;
		Else
			DataQuery.Text = CompositionTemplate.DataSets.SystemData.Items["GeneralRounding"].Query;
		EndIf;	
		
		For Each Parameter In CompositionTemplate.ParameterValues Do
			DataQuery.SetParameter(Parameter.Name,Parameter.Value);
		EndDo;	
		
	EndIf;
	
	If NOT IsBlankString(DataQuery.Text) Then
		
		QueryResultItem = DataQuery.Execute();
		Selection = QueryResultItem.Select();
		
		LineNumber = 0;
		While Selection.Next() Do
			
			For Each Column In QueryResultItem.Columns Do
				
				FoundRow = TablesProcessingAtClientAtServer.FindTabularPartRow(Parameters,New Structure("FieldName, ParameterKind",Column.Name,Enums.BookkeepingOperationTemplateParameterKinds.SystemData));
				
				If FoundRow <> Undefined Then
					NewRow = CalculatedParameters.Add();
					NewRow.LineNumber = LineNumber;
					NewRow.Name = FoundRow.Name;
					NewRow.Value = Selection[Column.Name];
				EndIf;
				
			EndDo;	
			
			Break;
			
		EndDo;	
		
	EndIf;	
	
	NewRow = BookkeepingDocumentObjectRecords.Add();
	NewRow.Type = Enums.BookkeepingOperationRecordTypes.Auto;
	
	ExchangeRateDifferencesStructure = New Structure("Account, ExtDimension1, ExtDimension2, ExtDimension3");
	For Each KeyAndValue In ParametersMap Do
		If ExchangeRateDifferencesStructure.Property(KeyAndValue.Key) Then	
			NewRow[KeyAndValue.Key] = CalculateFormula(KeyAndValue.Value,NewRow,BookkeepingDocumentObjectRecords,BookkeepingDocumentObjectRecordsVT,CalculatedParameters,0);
		EndIf;	
	EndDo;	
	
	If ExchangeRateDifference<0 Then
		NewRow.AmountDr = abs(ExchangeRateDifference);
	Else
		NewRow.AmountCr = abs(ExchangeRateDifference);
	EndIf;
	
	If NewRow.Account.Currency Then
		NewRow.Currency = Constants.NationalCurrency.Get();
		NewRow.CurrencyAmount = abs(ExchangeRateDifference);
	EndIf	

EndProcedure	

Procedure ExecuteAlgorithmInScope(AlgorithmText,RecordsSet,RecordsArrayBySourceRecords,CalculatedParameters)
	
	ParametersSet = New Structure();
	
	For Each CalculatedParameter In CalculatedParameters Do
		
		If CalculatedParameter.LineNumber = 0 AND NOT ParametersSet.Property(CalculatedParameter.Name) Then
			ParametersSet.Insert(CalculatedParameter.Name, CalculatedParameter.Value);
		EndIf;	
		
	EndDo;	
	
	Execute(AlgorithmText);
	
EndProcedure	


Function GetTableOfTables(OtherSynonym = Undefined) Export
	
	TableOfTables = GetTableStructureForSelectedTables();
	
	If DocumentBase<>Undefined Then
		
		MetadataObject = DocumentBase.Metadata();
		
		For Each MetadataObjectItem In MetadataObject.TabularSections Do
			
			NewRow = TableOfTables.Add();
			NewRow.TableName = MetadataObjectItem.Name;
			NewRow.TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection;
			NewRow.TableSynonym = MetadataObjectItem.Synonym;
			NewRow.TablePicture = PictureLib.TabularSection;
			
		EndDo;	
		
		For Each MetadataObjectItem In MetadataObject.RegisterRecords Do
			
			MetadataType = Enums.BookkeepingOperationTemplateTableKind.DocumentRecords;
			
			If Metadata.InformationRegisters.Contains(MetadataObjectItem) Then
				
				If MetadataObjectItem.InformationRegisterPeriodicity = Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical then
					
					MetadataType = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterNonperiodic;
					
				Else
					
					MetadataType = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterPeriodic;
					
				EndIf;
				
				TablePicture = PictureLib.InformationRegister;
				
			ElsIf Metadata.AccumulationRegisters.Contains(MetadataObjectItem) Then
				
				MetadataType = Enums.BookkeepingOperationTemplateTableKind.AccumulationRegister;
				
				TablePicture = PictureLib.AccumulationRegister;
				
			EndIf;
			
			NewRow = TableOfTables.Add();
			NewRow.TableName = MetadataObjectItem.Name;
			NewRow.TableKind = MetadataType;
			NewRow.TableSynonym = MetadataObjectItem.Synonym;
			NewRow.TablePicture = TablePicture;
			
		EndDo;
		
	EndIf;

	NewRow = TableOfTables.Add();
	NewRow.TableName = "";
	NewRow.TableKind = Enums.BookkeepingOperationTemplateTableKind.DocumentRecords;
	If OtherSynonym = Undefined Then
		NewRow.TableSynonym = Nstr("en='Document records';pl='Zapisy dokumentu'");
	Else
		NewRow.TableSynonym = OtherSynonym;
	EndIf;	
	NewRow.TablePicture = PictureLib.RecordsByDocument;
	
	Return TableOfTables;
	
EndFunction

Function GetTableStructureForSelectedTables()
	
	TableStructureForSelectedTables = New ValueTable();
	
	TableStructureForSelectedTables.Columns.Add("TableName");
	TableStructureForSelectedTables.Columns.Add("TableSynonym");
	TableStructureForSelectedTables.Columns.Add("TableKind");
	TableStructureForSelectedTables.Columns.Add("TablePicture");
	TableStructureForSelectedTables.Columns.Add("Filter");
	
	Return TableStructureForSelectedTables;
	
EndFunction

#If Client Then

Function GetTreeStructureForSelectedTables()
	
	TableStructureForSelectedTables = New ValueTree();
	
	TableStructureForSelectedTables.Columns.Add("TableName");
	TableStructureForSelectedTables.Columns.Add("TableSynonym");
	TableStructureForSelectedTables.Columns.Add("TableKind");
	TableStructureForSelectedTables.Columns.Add("TablePicture");
	TableStructureForSelectedTables.Columns.Add("Filter");
	TableStructureForSelectedTables.Columns.Add("Availability");
	
	Return TableStructureForSelectedTables;
	
EndFunction	

Function GetKindPicture(TableKind) Export
	
	If TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection Then
		
		TablePicture = PictureLib.TabularSection;
		
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterNonperiodic
		OR TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterPeriodic Then
	
		TablePicture = PictureLib.InformationRegister;
		
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.AccumulationRegister Then	
		
		TablePicture = PictureLib.AccumulationRegister;
				
	Else
		
		TablePicture = PictureLib.RecordsByDocument;
		
	EndIf;

	Return  TablePicture;
	
EndFunction	

Function GetParentRowsByKind(TableKind, AllRecords) Export
	
	If TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection Then
		
		TabularSectionRows = AllRecords.Rows.Find("AllTabularSections","TableName",False);
		
		If TabularSectionRows = Undefined Then
			
			TabularSectionRows = AllRecords.Rows.Add();
			TabularSectionRows.TableName = "AllTabularSections";
			TabularSectionRows.TableSynonym = Nstr("en = 'Tabular sections'; pl = 'Sekcje tabelaryczne'");
			TabularSectionRows.TableKind = Enums.BookkeepingOperationTemplateTableKind.EmptyRef();
			TabularSectionRows.TablePicture = PictureLib.TabularSectionGroup;
			TabularSectionRows.Filter = New ValueList();
			TabularSectionRows.Filter.Add(Enums.BookkeepingOperationTemplateTableKind.TabularSection);
			
		EndIf;	
		
		TablePicture = PictureLib.TabularSection;
		
		ParentRows = TabularSectionRows; 
		
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterNonperiodic
		OR TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterPeriodic Then
		
		InformationRegisterRows = AllRecords.Rows.Find("AllInformationRegisters","TableName",False);
		
		If InformationRegisterRows = Undefined Then
			
			InformationRegisterRows = AllRecords.Rows.Add();
			InformationRegisterRows.TableName = "AllInformationRegisters";
			InformationRegisterRows.TableSynonym = Nstr("en = 'Information registers'; pl = 'Rejestry informacji'");
			InformationRegisterRows.TableKind = Enums.BookkeepingOperationTemplateTableKind.EmptyRef();
			InformationRegisterRows.TablePicture = PictureLib.InformationRegistersGroup;
			InformationRegisterRows.Filter = New ValueList();
			InformationRegisterRows.Filter.Add(Enums.BookkeepingOperationTemplateTableKind.InformationRegisterNonperiodic);
			InformationRegisterRows.Filter.Add(Enums.BookkeepingOperationTemplateTableKind.InformationRegisterPeriodic);
			
		EndIf;	
		
		TablePicture = PictureLib.InformationRegister;
		
		ParentRows = InformationRegisterRows; 
		
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.AccumulationRegister Then	
		
		AccumulationRegisterRows = AllRecords.Rows.Find("AllAccumulationRegisters","TableName",False);
		
		If AccumulationRegisterRows = Undefined Then
			
			AccumulationRegisterRows = AllRecords.Rows.Add();
			AccumulationRegisterRows.TableName = "AllAccumulationRegisters";
			AccumulationRegisterRows.TableSynonym = Nstr("en = 'Accumulation registers'; pl = 'Rejestry akumulacji'");
			AccumulationRegisterRows.TableKind = Enums.BookkeepingOperationTemplateTableKind.EmptyRef();
			AccumulationRegisterRows.TablePicture = PictureLib.AccumulationRegistersGroup;
			AccumulationRegisterRows.Filter = New ValueList();
			AccumulationRegisterRows.Filter.Add(Enums.BookkeepingOperationTemplateTableKind.AccumulationRegister);
			
		EndIf;	
		
		TablePicture = PictureLib.AccumulationRegister;
		
		ParentRows = AccumulationRegisterRows; 
		
	Else
		
		ParentRows = AllRecords; 
		
	EndIf;
	
	Return ParentRows;
	
EndFunction	

Procedure GetUsedTablesTableFromSelectedTablesTree(SelectedTablesTree,UsedTablesTable)
		
	If SelectedTablesTree<> Undefined Then
		
		For Each Row In SelectedTablesTree.Rows Do
			
			If Row.Rows.Count() = 0 Then
				
				If Row.Parent <> Undefined Then
					
					NewRow = UsedTablesTable.Add();
					NewRow.TableName = Row.TableName;
					NewRow.TableKind = Row.TableKind;
					
				EndIf; 
				
			Else
								
				GetUsedTablesTableFromSelectedTablesTree(Row,UsedTablesTable);
				
			EndIf;	
			
		EndDo;	
		
	EndIf;
	
EndProcedure	

Function GetAvailabilityForAllChildRows(Rows)
	
	AtLeastOneRowAvailable = False;
	
	For Each Row In Rows Do
		
		If Row.Rows.Count()>0 Then
			Row.Availability = GetAvailabilityForAllChildRows(Row.Rows);
		EndIf;	
		
		If Row.Availability Then 
			AtLeastOneRowAvailable = True;
		EndIf;	
		
	EndDo;	
	
	Return AtLeastOneRowAvailable; 
	
EndFunction	

// SelectedTables - table values from which will be excluded from available fields
// OtherSynonym - synonym for tabel with document's records
// TableKindFilter - Filter, which contains ValueList with available kinds. May be undefined
// TableNameFilter - Filter, which contains Name of table which should be selected. This filter is active only if TableKindFilter is not undefined. May be undefined
Function GetListOfAvailableTables(SelectedTables = Undefined, OtherSynonym = Undefined, TableKindFilter = Undefined, TableNameFilter = Undefined) Export
	
	TableOfTables = GetTableOfTables(OtherSynonym);
	ListOfAvailableTables = GetTreeStructureForSelectedTables();
	
	UsedTablesTable = New ValueTable();
	UsedTablesTable.Columns.Add("TableName");
	UsedTablesTable.Columns.Add("TableKind");
	
	GetUsedTablesTableFromSelectedTablesTree(SelectedTables,UsedTablesTable);
	
	TableOfTables.Sort("TableKind, TableSynonym");
	
	TabularSectionRows = Undefined;
	InformationRegisterRows = Undefined;
	AccumulationRegisterRows = Undefined;
	
	For Each Row In TableOfTables Do
		
		If IsCorrespondsToFilter(Row.TableName,Row.TableKind,TableKindFilter, TableNameFilter) Then
			
			ParentRows = GetParentRowsByKind(Row.TableKind,ListOfAvailableTables);
									
			NewRow = ParentRows.Rows.Add();
			NewRow.TableName = Row.TableName;
			NewRow.TableKind = Row.TableKind;
			NewRow.TableSynonym = Row.TableSynonym;
			NewRow.TablePicture = Row.TablePicture;
			NewRow.Availability = NOT IsTableWasUsedInSelectedTables(UsedTablesTable,Row.TableName,Row.TableKind);  		
			
		EndIf;	
		
	EndDo;	
	
	GetAvailabilityForAllChildRows(ListOfAvailableTables.Rows);
	
	Return ListOfAvailableTables;
	
EndFunction	

// Searches in SelectedTablesRows not available tables
Function GetListOfNotAvailableTables(SelectedTablesRows,TableOfTables=Undefined,ListOfNotAvailableTables = Undefined) Export
	
	If TableOfTables = Undefined Then
		TableOfTables = GetTableOfTables();
	EndIf;
	
	If ListOfNotAvailableTables = Undefined Then
		ListOfNotAvailableTables = New Array();
	EndIf;	

	For Each SelectedTablesRow In SelectedTablesRows Do
		
		If SelectedTablesRow.Rows.Count()>0 Then
			GetListOfNotAvailableTables(SelectedTablesRow.Rows, TableOfTables, ListOfNotAvailableTables);
		Else
			If SelectedTablesRow.Parent <> Undefined Then
				If TablesProcessingAtClientAtServer.FindTabularPartRow(TableOfTables, New Structure("TableName, TableKind", SelectedTablesRow.TableName, SelectedTablesRow.TableKind)) = Undefined Then
					ListOfNotAvailableTables.Add(SelectedTablesRow);
				EndIf;	
			EndIf;
		EndIf;	
		
	EndDo;	
	
	Return ListOfNotAvailableTables;
	
EndFunction 	

// Row - Structure which should contains 2 fields, TableName and TableKind
// TableKindFilter - Filter, which contains ValueList with available kinds. May be undefined
// TableNameFilter - Filter, which contains Name of table which should be selected. This filter is active only if TableKindFilter is not undefined. May be undefined.
Function IsCorrespondsToFilter(TableName, TableKind, TableKindFilter = Undefined, TableNameFilter = Undefined)
	
	CorrespondsToFilter = True;
	
	If TableKindFilter <> Undefined AND TableKindFilter.Count()>0 Then
		
		If TableKindFilter.FindByValue(TableKind)<> Undefined Then
			If TableNameFilter <> Undefined 
				AND TableKind <> Enums.BookkeepingOperationTemplateTableKind.DocumentRecords Then
				If TrimAll(Upper(TableNameFilter)) <> TrimAll(Upper(TableName)) Then
					CorrespondsToFilter = False;
				EndIf;	
			EndIf;	
		Else
			CorrespondsToFilter = False;
		EndIf;	
		
	EndIf;	
	
	Return CorrespondsToFilter;
	
EndFunction	

Function IsTableWasUsedInSelectedTables(UsedTablesTable,TableName,TableKind)
	
	FoundRows = UsedTablesTable.FindRows(New Structure("TableName, TableKind",TableName,TableKind));
	Return (FoundRows.Count()<>0);
	
EndFunction	

// Calls setting new parameter dialog
//
// Parameters
// TableBox - table to current column and row of which should be added parameter. May be Undefined.
// VTRow - Current value table row. If undefined then current row of TableBox is taken.
// ColumnName - Current column. If empty then current column of TableBox is taken.
// FormOwner - FormOwner of the modal window
//
// Return Value:
//  String: ParameterName
Function NewParameter(TableBox = Undefined , VTRow = Undefined, ColumnName = "", FormOwner = Undefined) Export

	ParameterForm = GetForm("Parameter", FormOwner);
	ParameterForm.DocumentBase = DocumentBase; 
	ParameterForm.Object = ThisObject;

	If TableBox <> Undefined Then 
		
		If VTRow = Undefined Then
			CurrentData = TableBox.CurrentData;
		Else
			CurrentData = VTRow;
		EndIf;	
		
		If CurrentData <> Undefined Then
			
			If ColumnName = "" Then
				If TableBox.CurrentColumn<>Undefined Then
					CurrentColumnName = TableBox.CurrentColumn.Name;
				Else
					CurrentColumnName = Undefined;
				EndIf;	
			Else
				CurrentColumnName = ColumnName;
			EndIf;	
			
		EndIf;	
		
		If CurrentData<> Undefined
			AND CurrentColumnName<>Undefined
			AND CurrentColumnName <> "LineNumber"
			AND CurrentColumnName <> "Condition" Then
			
			ExtDimensionDescription = "";
			ColumnTypes          = Accounting.GetAccountingRecordsColumnType(Metadata(), TableBox, CurrentData, CurrentColumnName, ExtDimensionDescription);
			
			ParameterForm.TypeRestriction  = ColumnTypes;
			TableKindFilter = New ValueList();
			TableKindFilter.Add(Enums.BookkeepingOperationTemplateTableKind.DocumentRecords);
			If Common.IsDocumentTabularPartAttribute("TableKind",ThisObject.Metadata(),TableBox.Data)
				AND Common.IsDocumentTabularPartAttribute("TableName",ThisObject.Metadata(),TableBox.Data) Then
				
				If TableKindFilter.FindByValue(TableBox.CurrentData.TableKind) = Undefined Then
					TableKindFilter.Add(TableBox.CurrentData.TableKind);
				EndIf;	
				ParameterForm.TableKind = TableBox.CurrentData.TableKind;
				ParameterForm.TableName = TableBox.CurrentData.TableName;
				
			Else
				
				ParameterForm.TableKind = Enums.BookkeepingOperationTemplateTableKind.DocumentRecords;
				ParameterForm.TableName = "";
				
			EndIf;	
			
			If DocumentBase<> Undefined Then
				ParameterForm.ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.LinkedToDocumentBase;
			EndIf;	
			ParameterForm.TableKindFilter = TableKindFilter;
						
		EndIf;
		
	EndIf;

	Param = ParameterForm.DoModal();
	Return Param;

EndFunction // NewParameter()

// Set formula's expression for given field
//
// Parameters:
//  TableBox - control of table box Records
//  VTRow       - row of table box Records
//  ColumnName     - column Name of table box Records, formula for which should be set
//  FormulaStructure     - Structure - formula structure. Should contains FillingMethod and Value
// 
Procedure SetFormulaStructure(TableBox, VTRow="", ColumnName="", FormulaStructure=Undefined) Export

	If VTRow = "" Then
		VTRow = TableBox.CurrentData;
	EndIf;
		
	If ColumnName = "" Then
		ColumnName = TableBox.CurrentColumn.Name;
	EndIf;

	FormulasMapAsInternalString = TrimAll(VTRow.Formulas);
	If FormulasMapAsInternalString = "" Then
		FormulasMap = New Map();
	Else
		FormulasMap = ValueFromStringInternal(FormulasMapAsInternalString);
	EndIf;
	
	FormulasMap.Insert(TrimAll(ColumnName),FormulaStructure);
	
	VTRow.Formulas = ValueToStringInternal(FormulasMap);

EndProcedure

//  Returns parameters array corresponding with given type description
//
// Parameters:
//  TypeDescription   - TypeDescription Object
//
// Return Value:
//  Parameters array corresponding with given type description
//
Function GetParametersArray(TypeDescription) Export

	ParametersArray = New Array;

	If TypeDescription = Undefined Then
		Return ParametersArray
	EndIf;

	For each Param In Parameters Do

		ParameterTypeDescription = Param.Type.Get();

		For each T In TypeDescription.Types() Do

			If not ValueIsNotFilled(ParameterTypeDescription) Then
				If ParameterTypeDescription.ContainsType(T) Then
					ParametersArray.Add(Param.Name);
					Break;
				EndIf;
			EndIf;

		EndDo;

	EndDo;

	Return ParametersArray;

EndFunction

// Returns parameters array corresponding with given type description
//
// Parameters:
//  TypeDescription   - TypeDescription Object
//
// Return Value:
//  Parameters value list corresponding with given type description
// 
Function GetParametersValueList(TypeDescription, TableKind, TableName) Export

	ParametersValueList = New ValueList;
	
	For each Param In Parameters Do

		
		If Param.ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.LinkedToDocumentBase 
			AND Param.TableKind <> Enums.BookkeepingOperationTemplateTableKind.DocumentRecords Then
			
			If Param.TableKind <> TableKind OR Upper(TrimAll(Param.TableName))<>Upper(TrimAll(TableName)) Then
				Continue;
			EndIf;	
			
		EndIf;	
		
		If TypeDescription = Undefined Then
			ParametersValueList.Add(Param.Name,Param.Presentation);
		Else	
			ParameterTypeDescription = Param.Type.Get();
			
			For each T In TypeDescription.Types() Do
				
				If not ValueIsNotFilled(ParameterTypeDescription) Then
					If ParameterTypeDescription.ContainsType(T) Then
						ParametersValueList.Add(Param.Name,Param.Presentation);
						Break;
					EndIf;
				EndIf;
				
			EndDo;
		EndIf;

	EndDo;

	Return ParametersValueList;

EndFunction

Function GetParameterPresentationByName(ParameterName,RecordsTableBox = Undefined) Export
	
	FoundDot = Find(ParameterName,".");
	If FoundDot>0 Then
		
		If RecordsTableBox = Undefined Then
			Return Undefined;
		EndIf;
		
		// Get presentation from metadata
		RecordNumber = Number(Left(ParameterName,FoundDot));
		RecordField = Mid(ParameterName,FoundDot+1);
		
		Try
		
			Presentation = Nstr("en = 'Record'; pl = 'Zapis'") + RecordNumber + "." + Metadata().TabularSections[RecordsTableBox.Data].Attributes[RecordField].Synonym;
		
		Except
			
			Presentation = Undefined;
			
		EndTry; 
		
		Return Presentation;
		
	Else
		// get presentation from parameters
		FoundRow = TablesProcessingAtClientAtServer.FindTabularPartRow(Parameters,New Structure("Name",ParameterName));
		If FoundRow <> Undefined Then
			Return FoundRow.Presentation;
		Else
			Return Undefined;
		EndIf;	
		
	EndIf;
	
EndFunction	

Function GetRecordPresentation() Export
	
	Return Nstr("en = 'Record'; pl = 'Zapis'");
	
EndFunction	

Function GetParameterNameByPresentation(ParameterPresentation, TableKind, TableName,RecordsTableBox = Undefined) Export
	
	FoundDot = Find(ParameterPresentation,".");
	
	If FoundDot>1 Then
		MaybeRecord = Left(ParameterPresentation,FoundDot-1);
		RecordPresentation = GetRecordPresentation();
		FoundRecord = Find(MaybeRecord,RecordPresentation);
		If FoundRecord=1 Then
			NumberAsString = Mid(MaybeRecord,StrLen(RecordPresentation)+1);
			
			Try
			
				Number = Number(NumberAsString);
			
			Except
				
				Number = 0;
				
			EndTry; 
			
			If Number<>0 AND RecordsTableBox <> Undefined Then
				
				Field = Upper(TrimAll(Mid(ParameterPresentation,FoundDot+1)));
				For Each Attribute In Metadata().TabularSections[RecordsTableBox.Data].Attributes Do
					
					If Field = Upper(TrimAll(Attribute.Synonym)) Then
						
						Return ""+Number +"." + Attribute.Name;
						
					EndIf;	
					
				EndDo;	
				
			EndIf;	
			
		EndIf;	
		
	EndIf;
	
	FoundRows = Parameters.FindRows(New Structure("Presentation",ParameterPresentation));
	
	AvailableRows = New Array;
	AvailableRowsByDocumentRecords = New Array;
	
	For Each FoundRow In FoundRows Do
		
		If FoundRow.TableKind = TableKind 
			AND Upper(TrimAll(FoundRow.TableName)) = Upper(TrimAll(TableName)) Then
			
			AvailableRows.Add(FoundRow);	
			
		ElsIf FoundRow.TableKind = Enums.BookkeepingOperationTemplateTableKind.DocumentRecords Then
			
			AvailableRowsByDocumentRecords.Add(FoundRow);	
			
		EndIf;	
		
	EndDo;	
	
	If AvailableRows.Count()=1 Then
		Return AvailableRows[0].Name;
	ElsIf AvailableRows.Count()>1 Then
		Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Too many parameters with name %P1 found!'; pl = 'Dużo parametrów o nazwie %P1 znaleziono!'"),New Structure("P1",ParameterPresentation)));
		Return Undefined;
	ElsIf AvailableRowsByDocumentRecords.Count()=1 Then
		Return AvailableRowsByDocumentRecords[0].Name;
	ElsIf AvailableRowsByDocumentRecords.Count()>1 Then	
		Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Too many parameters with name %P1 found!'; pl = 'Dużo parametrów o nazwie %P1 znaleziono!'"),New Structure("P1",ParameterPresentation)));
		Return Undefined;
	Else
		Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'No parameters with name %P1 found!'; pl = 'Parametrów o nazwie %P1 nie znaleziono!'"),New Structure("P1",ParameterPresentation)));
		Return Undefined;
	EndIf;	
	
EndFunction	

Function GetFormulaByFormulaPresentation(FormulaPresentation, TableKind, TableName,RecordsTableBox = Undefined) Export
	
	Formula = "";
	FormulaPresentationSubstring = FormulaPresentation;
	FormulaToEval = "";
	While True Do
		
		FoundParameterStart = Find(FormulaPresentationSubstring,"[");
		If FoundParameterStart = 0 Then
			
			Formula = Formula + FormulaPresentationSubstring;
			FormulaToEval = FormulaToEval + FormulaPresentationSubstring;
			
			Try
			
				Res = Eval(FormulaToEval);
			
			Except
				
				Return "";
			
			EndTry; 
			
			Return Formula;
			
		Else	
			
			Formula = Formula + Left(FormulaPresentationSubstring,FoundParameterStart-1);
			FormulaToEval = FormulaToEval + Left(FormulaPresentationSubstring,FoundParameterStart-1);
			FormulaPresentationSubstring = Right(FormulaPresentationSubstring,StrLen(FormulaPresentationSubstring)-FoundParameterStart);
			FoundParameterEnd = Find(FormulaPresentationSubstring,"]");
			If FoundParameterEnd = 0 Then
				Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Not found '']'' for parameter %P1!'; pl = 'Oczekuje się '']'' dla parametru %P1!'"), New Structure("P1",FormulaPresentationSubstring)));
				Return "";
			Else
				ParameterPresentation = Left(FormulaPresentationSubstring,FoundParameterEnd-1);
				FormulaPresentationSubstring = Right(FormulaPresentationSubstring,StrLen(FormulaPresentationSubstring)-FoundParameterEnd);
				ParameterName = GetParameterNameByPresentation(ParameterPresentation,TableKind,TableName,RecordsTableBox);
				If ParameterName = Undefined Then
					Return "";
				Else
					Formula = Formula + "["+ParameterName+"]";
					FormulaToEval = FormulaToEval + "(1)";
				EndIf;	
			EndIf;	
			
		EndIf;
		
	EndDo;	
	
EndFunction	

Function GetFormulaPresentationByFormula(Formula,RecordsTableBox = Undefined) Export
	
	FormulaPresentation = "";
	FormulaSubstring = Formula;
	While True Do
		
		FoundParameterStart = Find(FormulaSubstring,"[");
		If FoundParameterStart = 0 Then
			
			FormulaPresentation = FormulaPresentation + FormulaSubstring;
			Return FormulaPresentation;
			
		Else	
			
			FormulaPresentation = FormulaPresentation + Left(FormulaSubstring,FoundParameterStart-1);
			FormulaSubstring = Right(FormulaSubstring,StrLen(FormulaSubstring)-FoundParameterStart);
			FoundParameterEnd = Find(FormulaSubstring,"]");
			If FoundParameterEnd = 0 Then
				Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Not found '']'' for parameter %P1!'; pl = 'Oczekuje się '']'' dla parametru %P1!'"), New Structure("P1",FormulaSubstring)));
				Return "";
			Else
				ParameterName = Left(FormulaSubstring,FoundParameterEnd-1);
				FormulaSubstring = Right(FormulaSubstring,StrLen(FormulaSubstring)-FoundParameterEnd);
				FormulaPresentation = FormulaPresentation + "["+GetParameterPresentationByName(ParameterName,RecordsTableBox)+"]";
			EndIf;	
			
		EndIf;
		
	EndDo;	
	
EndFunction	

Function GetFormulaPresentation(FormulaStructure,RecordsTableBox = Undefined) Export
	
	If FormulaStructure.FillingMethod = Enums.FieldFillingMethods.Parameter Then
		Return GetParameterPresentationByName(FormulaStructure.Value,RecordsTableBox);
	ElsIf FormulaStructure.FillingMethod = Enums.FieldFillingMethods.Formula Then	
		Return GetFormulaPresentationByFormula(FormulaStructure.Value,RecordsTableBox);
	ElsIf FormulaStructure.FillingMethod = Enums.FieldFillingMethods.ProgrammisticFormula Then
		If IsBlankString(TrimAll(FormulaStructure.Value)) Then
			Return "";
		Else	
			Return Nstr("en = 'Programmistic formula'; pl = 'Wzór programistyczny'");
		EndIf;	
	EndIf;	
	
EndFunction

Procedure EditParameter(ParameterName) Export
	
	If ParameterName = Undefined 
		Or IsBlankString(ParameterName) Then
		Return;
	EndIf;	
		
	CurParameter = TablesProcessingAtClientAtServer.FindTabularPartRow(Parameters,New Structure("Name",ParameterName));
	
	ParameterForm = GetForm("Parameter",);

	ParameterForm.Object = ThisObject;
	ParameterForm.DocumentBase = DocumentBase;
	ParameterForm.Parameter         = CurParameter;
	ParameterForm.Name              = CurParameter.Name;
	ParameterForm.Presentation    = CurParameter.Presentation;
	ParameterForm.Type              = ?(TrimAll(CurParameter.Type)<>"", CurParameter.Type.Get(), Undefined );
	ParameterForm.Value         = CurParameter.Value;
	ParameterForm.NotRequest    = CurParameter.NotRequest;
	ParameterForm.LinkByOwner = CurParameter.LinkByOwner;
	ParameterForm.LinkByType      = CurParameter.LinkByType;
	ParameterForm.ExtDimensionNumber    = CurParameter.ExtDimensionNumber;
	ParameterForm.LongDescription        = CurParameter.LongDescription;
	ParameterForm.Obligatory     = CurParameter.Obligatory;
	ParameterForm.ParameterKind     = CurParameter.ParameterKind;
	ParameterForm.ParameterFormula     = CurParameter.ParameterFormula;
	ParameterForm.TableName     = CurParameter.TableName;
	ParameterForm.TableKind     = CurParameter.TableKind;
	ParameterForm.TableKindFilter = Undefined;

	ParameterForm.DoModal();
	
EndProcedure	

Function EditFormula(FillingMethod, Formula, FormulaPresentation, TableKind, TableName, TableBox, TypeRestriction, FormOwner) Export
	
	If FillingMethod = Enums.FieldFillingMethods.Parameter Then
			
		SelectionForm = GetForm("ParameterSelection", FormOwner);
		SelectionForm.DocumentBase = DocumentBase;
		SelectionForm.FilterByType = True;
		SelectionForm.Caption   = Nstr("en = 'Choose parameter'; pl = 'Wybierz parametr'");
		SelectionForm.Controls.FilterByType.Visible = True;
		SelectionForm.Formula = Formula;
		SelectionForm.TableKind = TableKind;
		SelectionForm.TableName = TableName;
		SelectionForm.TableBox = TableBox;
		SelectionForm.TypeRestriction = TypeRestriction;
		SelectionForm.Object = ThisObject;
		
		SelectionForm.FillParametersTree();
		
		
		ParameterName = SelectionForm.DoModal();
		
		If ParameterName = Undefined Then
			Return Formula;
		Else
			Return ParameterName;
		EndIf;
		
	ElsIf FillingMethod = Enums.FieldFillingMethods.Formula Then	
		
		EditingFormulaForm = GetForm("EditFormulaSimple", FormOwner);
		EditingFormulaForm.DocumentBase = DocumentBase;
		EditingFormulaForm.Formula = Formula;
		EditingFormulaForm.TableKind = TableKind;
		EditingFormulaForm.TableName = TableName;
		EditingFormulaForm.TableBox = TableBox;
		EditingFormulaForm.Object = ThisObject;
		EditingFormulaForm.FormulaPresentation = FormulaPresentation;
		EditingFormulaForm.FillParametersTree();
		
		If EditingFormulaForm.DoModal()=True Then
			Return EditingFormulaForm.Formula;
		Else
			Return Formula;
		EndIf;	
		
	ElsIf FillingMethod = Enums.FieldFillingMethods.ProgrammisticFormula Then		
		
		EditingFormulaForm = GetForm("EditFormulaProgrammistic", FormOwner);
		EditingFormulaForm.DocumentBase = DocumentBase;
		EditingFormulaForm.Formula = Formula;
		EditingFormulaForm.TableKind = TableKind;
		EditingFormulaForm.TableName = TableName;
		EditingFormulaForm.TableBox = TableBox;
		EditingFormulaForm.Object = ThisObject;
		EditingFormulaForm.FillParametersTree();
		
		If EditingFormulaForm.DoModal()=True Then
			Formula = EditingFormulaForm.Formula;
		Else
			Return Formula;	
		EndIf;	
		
	EndIf;
	
	Return Formula;
	
EndFunction	

Procedure FillParametersTree(ParametersTreeControl,CurrentTableKind,CurrentTableName,CurrentFilterByType=False,CurrentTypeRestriction=Undefined,TableBox,CurrentRecord,ColumnName="",SkipCurrentColumn=False,ShowNames = False) Export

	ParametersTree = ParametersTreeControl.Value;
	ParametersTree.Rows.Clear();
	
	If CurrentTableKind = Enums.BookkeepingOperationTemplateTableKind.DocumentRecords 
		AND ThisObject[TableBox.Name].Count()>0 Then
		ParametersRow = ParametersTree.Rows.Add();
		ParametersRow.ParameterPresentation = Nstr("en='Parameters';pl='Parametry';");
	Else
		ParametersRow = ParametersTree;
	EndIf;
	
	ParametersValueList = GetParametersValueList(?(CurrentFilterByType,CurrentTypeRestriction,Undefined),CurrentTableKind,CurrentTableName);
	For each Param In ParametersValueList Do
		Row = ParametersRow.Rows.Add();
		Row.ParameterPresentation = Param.Presentation + ?(ShowNames," ("+Param.Value+")","");
		Row.ParameterName  = Param.Value;
	EndDo;
	
	If CurrentTableKind = Enums.BookkeepingOperationTemplateTableKind.DocumentRecords
		AND TableBox <> Undefined Then
		
		If ParametersRow.Rows.Count() = 0 Then
			ParametersTree.Rows.Delete(0);
		Else
			ParametersTreeControl.Expand(ParametersRow, True);
		EndIf;
		For each Rec In ThisObject[TableBox.Name] Do
			
			IndexOfRecord = ThisObject[TableBox.Name].Indexof(Rec);
			RecordNumber  = IndexOfRecord+1;
			If RecordNumber > TableBox.CurrentData.LineNumber Then
				// skip all records after this
				Return;
			EndIf;
			
			RecordsRow = ParametersTree.Rows.Add();
			RecordsRow.ParameterName = RecordNumber;
			RecordsRow.ParameterPresentation = GetRecordPresentation()+RecordNumber + ?(ShowNames," (Records["+IndexOfRecord+"])","");
			
			For each MDAttribute In Metadata.Catalogs.BookkeepingOperationsTemplates.TabularSections[TableBox.Name].Attributes Do
				
				If MDAttribute.Name = "Formulas" 
					OR MDAttribute.Name = "Condition" 
					OR MDAttribute.Name = "TableName" 
					OR MDAttribute.Name = "TableKind" 
					OR (RecordNumber = TableBox.CurrentData.LineNumber
					AND MDAttribute.Name = TableBox.CurrentColumn.Data)Then
					Continue
				EndIf;
				
				If SkipCurrentColumn AND (Rec = CurrentRecord) AND (MDAttribute.Name = ColumnName) Then
					Continue
				EndIf;
				
				ExtDimensionDescription = "";
				FieldTypes = Accounting.GetAccountingRecordsColumnType(Metadata(), TableBox, Rec, MDAttribute.Name, ExtDimensionDescription);
				TempFlag = True;
				
				If CurrentFilterByType Then
					
					TempFlag = False;
					
					If FieldTypes = Undefined Then
						Continue
					EndIf;
					
					For each T In FieldTypes.Types() Do
						If CurrentTypeRestriction.ContainsType(T) Then
							TempFlag = True;
							Break;
						EndIf;
					EndDo;
					
				EndIf;
				
				If Not TempFlag Then
					Continue
				EndIf;
				
				RecordField = RecordsRow.Rows.Add();
				RecordField.ParameterPresentation = MDAttribute.Synonym + ?((ExtDimensionDescription <> "") AND (ExtDimensionDescription <> MDAttribute.Name), " (", "") + ExtDimensionDescription + ?((ExtDimensionDescription <> "") AND (ExtDimensionDescription<>MDAttribute.Name), ")", "") + ?(ShowNames," ("+MDAttribute.Name+")","");
				RecordField.ParameterName  = "" + RecordNumber + "." + MDAttribute.Name;
				
			EndDo;
			
			If RecordsRow.Rows.Count() = 0 Then
				ParametersTree.Rows.Delete(ParametersTree.Rows.Count()-1);
			Else
				ParametersTreeControl.Expand(RecordsRow, True);
			EndIf;
			
		EndDo;
		
	EndIf;

EndProcedure // FillParametersTree()

#EndIf

Function ApplyDocumentBaseTableChange(TableName,TableKind,DCS = Undefined) Export
	
	MetadataObject = DocumentBase.Metadata();
	
	DCS = New DataCompositionSchema;
	
	DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
	
	DataSource = TemplateReports.AddLocalDataSource(DCS);
	
	DataSet = TemplateReports.AddDataSetQuery(DCS.DataSets, DataSource);
	AdditionalFields = Undefined;
	DataSet.Query = GenerateQueryByMetadata(TableName,TableKind,AdditionalFields);
	
	MetadataAttributes = MetadataObject.Attributes;
	
	MetadataAttributesArray = New Array();
	
	If IsBlankString(TableName) Then
		NewField = TemplateReports.AddDataSetField(DCS.DataSets[0], "Ref", Nstr("en='Reference';pl='Odwołanie'"));
		NewField.AttributeUseRestriction.Field = True;
		TemplateReports.AddDataSetField(DCS.DataSets[0], "DeletionMark", Nstr("en='Deletion mark';pl='Zaznaczenie do usunięcia'"));
		TemplateReports.AddDataSetField(DCS.DataSets[0], "Date", Nstr("en='Date';pl='Data'"));
		If MetadataObject.Posting = Metadata.ObjectProperties.Posting.Allow Then
			TemplateReports.AddDataSetField(DCS.DataSets[0], "Posted", Nstr("en='Posted';pl='Zatwierdzony'"));
		EndIf;	
		If MetadataObject.NumberLength > 0 Then
			TemplateReports.AddDataSetField(DCS.DataSets[0], "Number", Nstr("en='Number';pl='Numer'"));
		EndIf;	
		MetadataAttributesArray.Add(MetadataAttributes);
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection Then	
		NewField = TemplateReports.AddDataSetField(DCS.DataSets[0], "Ref", Nstr("en='Reference';pl='Odwołanie'"));
		NewField.UseRestriction.Field = True;
		NewField.AttributeUseRestriction.Field = True;
		MetadataAttributes = MetadataObject.TabularSections[TableName].Attributes;
		MetadataAttributesArray.Add(MetadataAttributes);
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.AccumulationRegister Then	
		MetadataObject = Metadata.AccumulationRegisters[TableName];
		MetadataAttributesArray.Add(MetadataObject.Attributes);
		MetadataAttributesArray.Add(MetadataObject.Dimensions);
		MetadataAttributesArray.Add(MetadataObject.Resources);
		TemplateReports.AddDataSetField(DCS.DataSets[0], "Recorder", Nstr("en='Recorder';pl='Rejestrator'"));
		TemplateReports.AddDataSetField(DCS.DataSets[0], "Period", Nstr("en='Period';pl='Okres'"));
		If MetadataObject.RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Balance Then
			TemplateReports.AddDataSetField(DCS.DataSets[0], "RecordType", Nstr("en='Record type';pl='Typ zapisu'"));
		EndIf;	
		
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterPeriodic 
		OR TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterNonperiodic Then	
		MetadataObject = Metadata.InformationRegisters[TableName];
		MetadataAttributesArray.Add(MetadataObject.Attributes);
		MetadataAttributesArray.Add(MetadataObject.Dimensions);
		MetadataAttributesArray.Add(MetadataObject.Resources);
		TemplateReports.AddDataSetField(DCS.DataSets[0], "Recorder", Nstr("en='Recorder';pl='Rejestrator'"));
		If MetadataObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
			TemplateReports.AddDataSetField(DCS.DataSets[0], "Period", Nstr("en='Period';pl='Okres'"));
		EndIf;	
	EndIf;	
	
	For Each MetadataAttributesSet In MetadataAttributesArray Do
		For each Attribute In MetadataAttributesSet Do
			AddedField = TemplateReports.AddDataSetField(DCS.DataSets[0], Attribute.Name, Attribute.Synonym);
		EndDo;
	EndDo;
	
	For each AdditionalField In AdditionalFields Do
		AddedField = TemplateReports.AddDataSetField(DCS.DataSets[0], AdditionalField.Name, AdditionalField.Title, AdditionalField.DataPath);
	EndDo;	
	
	NewParameter = DCS.Parameters.Add();
	NewParameter.Name = "Period";
	NewParameter.IncludeInAvailableFields = False;
	
	//DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DCS));

	DCSInTempStorage = PutToTempStorage(DCS, New UUID());
	DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DCSInTempStorage));
	
	Return DataCompositionSettingsComposer;
	
EndFunction	

Function GenerateQueryByMetadata(TableName, TableKind,AdditionalDataSetFields)
		
	AdditionalDataTable = GetTableOfObjectsWithAdditionalFields();
	
	IncludedRegistersQuery = "";
	IncludedRegistersAndFields = New ValueTable();
	IncludedRegistersAndFields.Columns.Add("TableAlias");
	IncludedRegistersAndFields.Columns.Add("FieldName");
	IncludedRegistersAndFields.Columns.Add("TableName");
	
	AdditionalDataSetFields = New ValueTable();
	AdditionalDataSetFields.Columns.Add("Name");
	AdditionalDataSetFields.Columns.Add("Title");
	AdditionalDataSetFields.Columns.Add("DataPath");
	
	MetadataObject = DocumentBase.Metadata();
	
	SelectedAttributes = "";
	
	MetadataAttributesArray = New Array();
	
	If IsBlankString(TableName) Then
		MetadataAttributes = MetadataObject.Attributes;
		// Predefined items for document
		SelectedAttributes = SelectedAttributes +  "DataSource.Ref, DataSource.DeletionMark, DataSource.Date, ";
		If MetadataObject.Posting = Metadata.ObjectProperties.Posting.Allow Then
			SelectedAttributes = SelectedAttributes +  "DataSource.Posted, ";
		EndIf;	
		If MetadataObject.NumberLength > 0 Then
			SelectedAttributes = SelectedAttributes +  "DataSource.Number, ";
		EndIf;	
		MetadataAttributesArray.Add(MetadataAttributes);
		TableKindName = "Document";
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection Then
		SelectedAttributes = SelectedAttributes +  "DataSource.Ref, ";
		MetadataAttributes = MetadataObject.TabularSections[TableName].Attributes;
		MetadataAttributesArray.Add(MetadataAttributes);
		TableKindName = "Document";
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.AccumulationRegister Then	
		
		MetadataObject = Metadata.AccumulationRegisters[TableName];
		MetadataAttributesArray.Add(MetadataObject.Attributes);
		MetadataAttributesArray.Add(MetadataObject.Dimensions);
		MetadataAttributesArray.Add(MetadataObject.Resources);
		TableKindName = "AccumulationRegister";
		
		SelectedAttributes = SelectedAttributes +  "DataSource.Recorder, DataSource.Period, ";
		
		If MetadataObject.RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Balance Then
			SelectedAttributes = SelectedAttributes +  "DataSource.RecordType, ";
		EndIf;	
				
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterPeriodic 
		OR TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterNonperiodic Then	
		MetadataObject = Metadata.InformationRegisters[TableName];
		MetadataAttributesArray.Add(MetadataObject.Attributes);
		MetadataAttributesArray.Add(MetadataObject.Dimensions);
		MetadataAttributesArray.Add(MetadataObject.Resources);
		TableKindName = "InformationRegister";
		
		SelectedAttributes = SelectedAttributes +  "DataSource.Recorder, ";
		
		If MetadataObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
			SelectedAttributes = SelectedAttributes +  "DataSource.Period, ";
		EndIf;
		
	EndIf;	
	
	For Each MetadataAttributesSet In MetadataAttributesArray Do
		
		For each Attribute In MetadataAttributesSet Do
			
			SelectedAttributes = SelectedAttributes + "DataSource." + Attribute.Name + ", ";
			
			For Each AdditionalDataTableItem In AdditionalDataTable Do
				
				If Attribute.Type.ContainsType(TypeOf(AdditionalDataTableItem.Type)) Then
					
					InformationRegisterMetadata = Metadata.InformationRegisters[AdditionalDataTableItem.Register].Resources;
					
					LocalTableName = Attribute.Name + AdditionalDataTableItem.DataPath + AdditionalDataTableItem.Register;
					
					LocalAdditionalDataTableItemQuery = AdditionalDataTableItem.Query;
					LocalAdditionalDataTableItemQuery = StrReplace(LocalAdditionalDataTableItemQuery,"_OBJECT_","DataSource."+Attribute.Name);
					LocalAdditionalDataTableItemQuery = StrReplace(LocalAdditionalDataTableItemQuery,"_REGISTER_",LocalTableName);
					
					IncludedRegistersQuery = IncludedRegistersQuery + LocalAdditionalDataTableItemQuery;
					
					For Each InformationRegisterMetadataAttribute In InformationRegisterMetadata Do
						
						SelectedAttributes = SelectedAttributes + LocalTableName + "." + InformationRegisterMetadataAttribute.Name+" AS "+Attribute.Name + InformationRegisterMetadataAttribute.Name+", ";
						NewAdditionalDataSetField = AdditionalDataSetFields.Add();
						NewAdditionalDataSetField.Name = Attribute.Name + InformationRegisterMetadataAttribute.Name;
						NewAdditionalDataSetField.Title = Attribute.Synonym + "." +?(IsBlankString(AdditionalDataTableItem.DataPathSynonym),"",AdditionalDataTableItem.DataPathSynonym+".") + InformationRegisterMetadataAttribute.Synonym;
						NewAdditionalDataSetField.DataPath = Attribute.Name + "." + ?(IsBlankString(AdditionalDataTableItem.DataPath),"",AdditionalDataTableItem.DataPath+".")+ InformationRegisterMetadataAttribute.Name;
						
					EndDo;	
					
				EndIf;	
				
			EndDo;		
			
		EndDo;
		
	EndDo;
	
	SelectedAttributes = Left(SelectedAttributes,StrLen(SelectedAttributes)-2);
	
	
	QueryText = " SELECT ALLOWED " + Chars.LF;
	
	QueryText = QueryText + SelectedAttributes + 
	" FROM "+ TableKindName + "." + MetadataObject.Name;
	
	If Not IsBlankString(TableName) 
		AND (TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection 
		OR TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection) Then
		QueryText = QueryText + "." + TableName;
	EndIf;
	
	QueryText = QueryText + " AS DataSource" + IncludedRegistersQuery;
	
	Return QueryText;
	
EndFunction

Function GetTableOfObjectsWithAdditionalFields()
	
	AdditionalDataTable = New ValueTable;
	AdditionalDataTable.Columns.Add("Type");
	AdditionalDataTable.Columns.Add("DataPath");
	AdditionalDataTable.Columns.Add("Query");
	AdditionalDataTable.Columns.Add("Register");
	AdditionalDataTable.Columns.Add("DataPathSynonym");
		
	Template = GetTemplate("LinkToBookkeepingData");
	LinkToBookkeepingDataTemplateText = GetTemplate("LinkToBookkeepingDataTemplateText").GetText();
	LinkToBookkeepingDataTemplate = Common.GetObjectFromXML(LinkToBookkeepingDataTemplateText,Type("DataCompositionSchema"));
	
	XMLContenMap = AdditionalInformationRepository.GetContentMapFromXML(Template.GetText());
	LinkToBookkeepingData = XMLContenMap.Get("LinkToBookkeepingData");
	If LinkToBookkeepingData <> Undefined Then
		
		CatalogsLinks = LinkToBookkeepingData.Get("Catalogs");
		If CatalogsLinks <> Undefined Then
			
			For Each CatalogItem In CatalogsLinks Do
				
				CatalogItemData = CatalogItem.Value;
				If CatalogItemData = Undefined Then
					Continue;
				EndIf;	
				
				Try
					CatalogName = TrimAll(CatalogItemData.Get("Name"));
					CatalogType = Catalogs[CatalogName].EmptyRef();
					TypesArray = New ValueList();
					TypesArray.Add(TypeOf(CatalogType));
				Except
					Continue;
				EndTry;	
				
				Try
					RegisterName = TrimAll(CatalogItemData.Get("Register"));
					Register = InformationRegisters[RegisterName];
				Except
					Continue;
				EndTry;
				
				CatalogDataPath = CatalogItemData.Get("Datapath");
				DataPathSynonym = "";
				If CatalogDataPath <> Undefined 
					AND NOT IsBlankString(CatalogDataPath) Then
					BufCatalogDataPath = CatalogDataPath;
					FoundDot = Find(BufCatalogDataPath,".");
					While NOT IsBlankString(BufCatalogDataPath) Do
						If FoundDot = 0 Then
							CurrentPartOfPath = BufCatalogDataPath;
						Else	
							CurrentPartOfPath = Left(BufCatalogDataPath,FoundDot-1);
						EndIf;	
						NewTypesArray = New ValueList();
						CurrentSynonym = "";
						For Each TypeItem In TypesArray Do
							CurrentNewType = New (TypeItem.Value);
							CurrentMetadata = CurrentNewType.Metadata();	
							If CommonAtServer.IsDocumentAttribute(CurrentPartOfPath,CurrentMetadata) Then
								CurrentSynonym = CurrentMetadata.Attributes[CurrentPartOfPath].Synonym;
								For Each MetadataType In CurrentMetadata.Attributes[CurrentPartOfPath].Type.Types() Do
									If NewTypesArray.FindByValue(MetadataType) = Undefined Then
										NewTypesArray.Add(MetadataType);
									EndIf;	
								EndDo;	
							EndIf;	
						EndDo;
						If NOT IsBlankString(CurrentSynonym) Then
							DataPathSynonym = DataPathSynonym + ?(IsBlankString(DataPathSynonym),CurrentSynonym,"."+CurrentSynonym);
						EndIf;	
						BufCatalogDataPath = Right(BufCatalogDataPath,StrLen(BufCatalogDataPath)-FoundDot);
						FoundDot = Find(BufCatalogDataPath,".");
						If FoundDot = 0 Then 
							BufCatalogDataPath = "";
						EndIf;	
						TypesArray = NewTypesArray;
					EndDo;	
					
				EndIf;	

				QueryText = LinkToBookkeepingDataTemplate.DataSets[CatalogName].Query;
				LeftPos = Find(QueryText,"{");
				RightPos = Find(QueryText,"}");
				SelectedQueryText = Mid(QueryText,LeftPos,RightPos-LeftPos+1);
				
				NewRow = AdditionalDataTable.Add();
				NewRow.Type = CatalogType;
				
				NewRow.DataPath = TrimAll(?(CatalogDataPath=Undefined,"",CatalogDataPath));
				NewRow.DataPathSynonym = DataPathSynonym;
				NewRow.Query = SelectedQueryText;
				NewRow.Register = RegisterName;
				
			EndDo;	
			
		EndIf;	
		
	EndIf;	
			
	Return AdditionalDataTable;
	
EndFunction	

Function ValueListOfStructureFindByValue(ValueList, ValueToSearch) Export
	
	For Each Item In ValueList Do
		
		If TypeOf(Item.Value) <> TypeOf(ValueToSearch) Then
			Continue;
		EndIf;
		
		If TypeOf(ValueToSearch) = Type("Structure") Then
			If ValueToSearch.Count() <> Item.Value.Count() Then
				Continue;
			Else
				NotEqual = False;
				For Each KeyAndValue In ValueToSearch Do
					SecondValue = Undefined;
					If Item.Value.Property(KeyAndValue.Key,SecondValue) Then
						If SecondValue <> KeyAndValue.Value Then 
							NotEqual = True;
							Break;
						EndIf;
					Else
						NotEqual = True;
						Break;
					EndIf;	
				EndDo;	
				If NOT NotEqual Then
					Return Item;
				EndIf;	
			EndIf;	
		Else
			Return ValueList.FindByValue(ValueToSearch);
		EndIf;	
		
	EndDo;	
	
	Return Undefined;
	
EndFunction	

Function ParseStringIntoParametersMap(Val String) Export
	
	ParsedString = New ValueTable();
	ParsedString.Columns.Add("IsOperator");
	ParsedString.Columns.Add("Name");
	
	AvailableOperatorsList = "()+-*/><=?;,";
	
	String = StrReplace(String," ","");
	
	CurrentField = "";
	StringLength = StrLen(String);

	For i = 1 To StringLength Do
		
		Char = Mid(String, i, 1);
		If Find(AvailableOperatorsList, Char) > 0 Then
			
			If Not IsBlankString(CurrentField) Then
				NewRow = ParsedString.Add();
				NewRow.IsOperator = False;
				NewRow.Name = CurrentField;
				CurrentField = "";
			EndIf;
		
			NewRow = ParsedString.Add();
			NewRow.IsOperator = True;
			NewRow.Name = Char;
			
		Else
			CurrentField = CurrentField + Char;
		EndIf;
		
	EndDo;
	
	If Not IsBlankString(CurrentField) Then
		NewRow = ParsedString.Add();
		NewRow.IsOperator = False;
		NewRow.Name = CurrentField;
	EndIf;

	Return ParsedString;
	
EndFunction	

// Returns Undefined if an error occurs
Function EvaluateOnParsedString(ParsedStringTable,CalculatedParameters,LineNumber,ExistingRecords=Undefined)
	
	
	// Create scope structure
	ScopeStructure = New Structure();
	If ExistingRecords <> Undefined Then
		
		For i=0 To ExistingRecords.Count()-1 Do
			ExistingRecordsRecord = ExistingRecords.Get(i);
			ScopeStructure.Insert("Record"+(i+1),ExistingRecordsRecord)
		EndDo;	
		
	EndIf;	
	// Structure to check name
	Checking = New Structure();
	ParameterIndex = 1;
	
	StringToEvaluate = "";
	
	For Each ParsedStringTableItem In ParsedStringTable Do
		
		If ParsedStringTableItem.IsOperator Then
			// operator
			StringToEvaluate = StringToEvaluate + ParsedStringTableItem.Name;
		Else
			// operand
			
			If Upper(ParsedStringTableItem.Name) = Upper("Type")
				OR Upper(ParsedStringTableItem.Name) = Upper("TypeOf") Then
				StringToEvaluate = StringToEvaluate + ParsedStringTableItem.Name;
				Continue;		
			EndIf;	
			
			// Check is it correct parameter name
			IsCorrectName = True;
			Try
				Checking.Insert(ParsedStringTableItem.Name, "111");
			Except
				IsCorrectName = False;
			EndTry;
			
			If IsCorrectName Then
				// parameter's name is correct
				FoundRows = CalculatedParameters.FindRows(New Structure("LineNumber, Name",LineNumber-1,ParsedStringTableItem.Name));
				
				If FoundRows.Count()=0 Then
					// Try to find parameter with 0 row
					FoundRows = CalculatedParameters.FindRows(New Structure("LineNumber, Name",0,ParsedStringTableItem.Name));
					If FoundRows.Count()>0 Then
						OneRow = FoundRows[0];
					Else
						OneRow = Undefined;
					EndIf;	
				Else
					OneRow = FoundRows[0];
				EndIf;	
				
				If OneRow <> Undefined Then
					StringToEvaluate = StringToEvaluate + "ScopeStructure.P"+ParameterIndex;
					ScopeStructure.Insert("P"+ParameterIndex,OneRow.Value);
					ParameterIndex = ParameterIndex + 1;
				Else
					Return Undefined;
				EndIf;	
				
			Else
				Buf = ParsedStringTableItem.Name;
				FoundDot = Find(Buf,".");
				If FoundDot>0 Then
					Buf = Left(Buf,FoundDot-1);
					If Upper(Left(Buf,6) = "Record") Then
						StringToEvaluate = StringToEvaluate + "ScopeStructure." + ParsedStringTableItem.Name;
						Continue;
					EndIf;	
				EndIf;	
				// parameter's name is incorrect. Check maybe this is a number
				StringToEvaluate = StringToEvaluate + ParsedStringTableItem.Name;
			EndIf;	
			
		EndIf;

	EndDo;	
	
	Try
		RetValue = Eval(StringToEvaluate);
	Except
		RetValue = Undefined;
	EndTry;	
	
	Return RetValue;
	
EndFunction	

Function CalculateFormula(FormulaStructure,CurrentRecord,RecordsSet,RecordsArrayBySourceRecords,CalculatedParameters,LineNumber) Export
	
	If FormulaStructure = Undefined Then
		Return Undefined;
	EndIf;	
	
	If FormulaStructure.FillingMethod = Enums.FieldFillingMethods.Parameter Then
		Return GetValueByParameter(FormulaStructure.Value,CalculatedParameters,LineNumber,RecordsSet);
	ElsIf FormulaStructure.FillingMethod = Enums.FieldFillingMethods.Formula Then
		Return GetValueByFormula(FormulaStructure.Value,CalculatedParameters,LineNumber,RecordsSet);
	ElsIf FormulaStructure.FillingMethod = Enums.FieldFillingMethods.ProgrammisticFormula Then
		Return ExecuteProgrammisticFormula(FormulaStructure.Value,CurrentRecord,RecordsSet,RecordsArrayBySourceRecords,CalculatedParameters,LineNumber);
	ElsIf FormulaStructure.FillingMethod = Enums.FieldFillingMethods.Value Then
		Return FormulaStructure.Value;	
	EndIf;	
	
EndFunction	

Function GetValueByParameter(ParameterName,CalculatedParameters,LineNumber,RecordsSet=Undefined) Export
	
	FoundDot = Find(ParameterName,".");
	If FoundDot = 0 Then
		// Parameter
		FoundRow = TablesProcessingAtClientAtServer.FindTabularPartRow(CalculatedParameters,New Structure("Name, LineNumber",ParameterName,LineNumber-1));
		If FoundRow = Undefined Then
			FoundRow = TablesProcessingAtClientAtServer.FindTabularPartRow(CalculatedParameters,New Structure("Name, LineNumber",ParameterName,0));
		EndIf;	
		If FoundRow = Undefined Then
			Return Undefined;
		Else
			Return FoundRow.Value;
		EndIf;	
	Else
		// maybe record (only for document records)
		Try
		
			RowNumber = Number(Left(ParameterName,FoundDot-1));
		
		Except
			
			RowNumber = 0;
		
		EndTry; 
		
		If RowNumber = 0 Then
			// not record
			Return Undefined;
		Else
			
			If RecordsSet = Undefined OR RecordsSet.Count()<(RowNumber-1) Then
				// could not get record
				Return Undefined;
			Else
				RecordInRecordsSet = RecordsSet[RowNumber-1];
				Try
					
					RetValue = RecordInRecordsSet[Mid(ParameterName,FoundDot+1)];
					
				Except
					
					RetValue = Undefined;
					
				EndTry;
				
				
			EndIf;	
			
			
			Return RetValue;
			
		EndIf;	
		
		
	EndIf;	
	
EndFunction	

Function GetValueByFormula(Formula,CalculatedParameters,LineNumber,RecordsSet=Undefined) Export
	
	ParameterIndex = 1;
	Scope = New Structure();
	FormulaInScope = "";
	FormulaSubstring = Formula;
	While True Do
		
		FoundParameterStart = Find(FormulaSubstring,"[");
		If FoundParameterStart = 0 Then
			
			FormulaInScope = FormulaInScope + FormulaSubstring;
			Break;
			
		Else	
			
			FormulaInScope = FormulaInScope + Left(FormulaSubstring,FoundParameterStart-1);
			FormulaSubstring = Right(FormulaSubstring,StrLen(FormulaSubstring)-FoundParameterStart);
			FoundParameterEnd = Find(FormulaSubstring,"]");
			If FoundParameterEnd = 0 Then
				ErrorText = Alerts.ParametrizeString(Nstr("en = 'Not found '']'' for parameter %P1!'; pl = 'Oczekuje się '']'' dla parametru %P1!'"), New Structure("P1",FormulaSubstring));
				FormulaInScope = "";
				Break;
			Else
				ParameterName = Left(FormulaSubstring,FoundParameterEnd-1);
				FormulaSubstring = Right(FormulaSubstring,StrLen(FormulaSubstring)-FoundParameterEnd);
				Scope.Insert("P"+ParameterIndex,GetValueByParameter(ParameterName,CalculatedParameters,LineNumber,RecordsSet));
				If Scope["P"+ParameterIndex] = Undefined Then
					Scope["P"+ParameterIndex] = 0;
				EndIf;	
				FormulaInScope = FormulaInScope + "Scope.P"+ParameterIndex;
				ParameterIndex = ParameterIndex + 1;
			EndIf;	
			
		EndIf;
		
	EndDo;	
	
	If IsBlankString(FormulaInScope) Then 
		Alerts.AddAlert(ErrorText);
		Return Undefined;
	Else
		Return Eval(FormulaInScope);
	EndIf;	
	
EndFunction	

Function ExecuteProgrammisticFormula(Formula,CurrentRecord,RecordsSet,RecordsArrayBySourceRecords,CalculatedParameters,LineNumber)
	
	// Scope
	CurrentField = Undefined;
	CurrentRow = Undefined;
	ParametersSet = New Structure();
	
	For Each CalculatedParameter In CalculatedParameters Do
		
		If CalculatedParameter.LineNumber = (LineNumber -1) Then
			ParametersSet.Insert(CalculatedParameter.Name, CalculatedParameter.Value);
		ElsIf CalculatedParameter.LineNumber = 0 AND NOT ParametersSet.Property(CalculatedParameter.Name) Then
			ParametersSet.Insert(CalculatedParameter.Name, CalculatedParameter.Value);
		EndIf;	
		
	EndDo;	
	
	Execute(Formula);
	
	Return CurrentField;
	
EndFunction	

Procedure UpdateTypeFromStringInternal() Export
	For Each CurrentParameter In Parameters Do
		CurrentParameter.Type = New ValueStorage(ValueFromStringInternal(CurrentParameter.TypeStringInternal));
	EndDo;
EndProcedure

Procedure UpdateStringInternalFromType() Export
	For Each CurrentParameter In Parameters Do
		CurrentParameter.TypeStringInternal = ValueToStringInternal(?(TrimAll(CurrentParameter.Type) <> "", CurrentParameter.Type.Get(), Undefined));
	EndDo;
EndProcedure

Procedure UpdateFilterAsXML() Export
	FilterAsXML = ?(TrimAll(Filter) <> "", Filter.Get(), "");
EndProcedure


