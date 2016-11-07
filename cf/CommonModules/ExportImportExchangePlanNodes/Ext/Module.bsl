// Fill the types array  when importing which,
// you must use the refs annotation in the import files.
//
// Parameters:
//  Types - Array(MetadataObject)
//
Procedure WhenFillingTypesRequireAnnotationRefsOnImport(Types) Export
	
	For Each ExchangePlan IN Metadata.ExchangePlans Do
		
		Types.Add(ExchangePlan);
		
	EndDo;
	
EndProcedure

Procedure WhenDataImportHandlersRegistration(HandlersTable) Export
	
	For Each ExchangePlan IN Metadata.ExchangePlans Do
		
		NewHandler = HandlersTable.Add();
		NewHandler.MetadataObject = ExchangePlan;
		NewHandler.Handler = ExportImportExchangePlanNodes;
		NewHandler.BeforeObjectExport = True;
		NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
		
	EndDo;
	
EndProcedure

Procedure BeforeObjectExport(Container, ObjectExportManager, Serializer, Object, Artifacts, Cancel) Export
	
	MetadataObject = Object.Metadata();
	
	If CommonUseSTL.ThisIsExchangePlan(MetadataObject) Then
		
		// Matching of refs to ThisNode nodes is supported when importing data
   
   Manager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
		ThisNode = Manager.ThisNode();
		
		If Object.Ref = ThisNode Then
			
			NaturalKey = New Structure("ThisNode", True);
			ObjectExportManager.RequireMatchRefOnImport(Object.Ref, NaturalKey);
			
		EndIf;
		
		// Export/import of the exchange plans nodes is not supported.
		
		Cancel = True;
		
	Else
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en='Metadata object %1 is can not
		|be processed by the handler 
		|ExportImportExchangePlanNodes.BeforeObjectExport ()!';ru='Объект метаданных %1 не может быть обработан обработчиком
		|ВыгрузкаЗагрузкаУзловПлановОбменов.ПередВыгрузкойОбъекта()!'", Metadata.DefaultLanguage.LanguageCode),
			Object.Metadata().FullName()
		);
		
	EndIf;
	
EndProcedure

Procedure WhenDataExportHandlersRegistration(HandlersTable) Export
	
	NewHandler = HandlersTable.Add();
	NewHandler.Handler = ExportImportExchangePlanNodes;
	NewHandler.BeforeDataImport = True;
	NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
	
	For Each ExchangePlan IN Metadata.ExchangePlans Do
		
		NewHandler = HandlersTable.Add();
		NewHandler.MetadataObject = ExchangePlan;
		NewHandler.Handler = ExportImportExchangePlanNodes;
		NewHandler.BeforeMatchRefs = True;
		NewHandler.BeforeObjectImport = True;
		NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
		
	EndDo;
	
EndProcedure

Procedure BeforeDataImport(Container) Export
	
	For Each ExchangePlan IN Metadata.ExchangePlans Do
		
		QueryText = "Select First 1 Ref From ExchangePlan." + ExchangePlan.Name;
		Query = New Query(QueryText);
		Query.Execute().Select();
		
	EndDo;
	
EndProcedure

Procedure BeforeMatchRefs(Container, MetadataObject, SourceRefsTable, StandardProcessing, Cancel) Export
	
	If CommonUseSTL.ThisIsExchangePlan(MetadataObject) AND SourceRefsTable.Columns.Find("ThisNode") <> Undefined Then
		
		StandardProcessing = False
		
	EndIf;
	
EndProcedure

Function MatchRefs(Container, RefsMappingManager, SourceRefsTable) Export
	
	SourceRefsForStandardProcessing = New ValueTable();
	For Each Column IN SourceRefsTable.Columns Do
		If Column.Name <> "ThisNode" Then
			SourceRefsForStandardProcessing.Columns.Add(Column.Name, Column.ValueType);
		EndIf;
	EndDo;
	
	ColumnName = RefsMappingManager.SourceRefsColumnName();
	
	Result = New ValueTable();
	Result.Columns.Add(ColumnName, SourceRefsTable.Columns.Find(ColumnName).ValueType);
	Result.Columns.Add("Ref", SourceRefsTable.Columns.Find(ColumnName).ValueType);
	
	MetadataObject = Undefined;
	
	For Each TableRowSourceLinks IN SourceRefsTable Do
		
		If TableRowSourceLinks.ThisNode Then
			
			MetadataObject = TableRowSourceLinks[ColumnName].Metadata();
			Manager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
			NewRef = Manager.ThisNode();
			
			ResultRow = Result.Add();
			ResultRow.Ref = NewRef;
			ResultRow[ColumnName] = TableRowSourceLinks[ColumnName];
			
		EndIf;
		
	EndDo;
	
	If SourceRefsForStandardProcessing.Count() > 0 Then
		
		Selection = DataProcessors.DataExportImportRefsMappingManager.MatchRefsSelection(
			MetadataObject, SourceRefsForStandardProcessing, ColumnName);
		
		While Selection.Next() Do
			
			ResultRow = Result.Add();
			ResultRow.Ref = Selection.Ref;
			ResultRow[ColumnName] = Selection[ColumnName];
			
		EndDo;
		
	EndIf;
	
	Return Result;
	
EndFunction

Procedure BeforeObjectImport(Container, Object, Artifacts, Cancel) Export
	
	MetadataObject = Object.Metadata();
	
	If CommonUseSTL.ThisIsExchangePlan(MetadataObject) Then
		
		Cancel = True; // Export of the exchange plans nodes is not supported
		
	Else
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en='Metadata object %1 is can not
		|be processed by the handler 
		|ExportImportExchangePlanNodes.BeforeObjectImport()!';ru='Объект метаданных %1 не может быть обработан обработчиком
		|ВыгрузкаЗагрузкаУзловПлановОбменов.ПередЗагрузкойОбъекта()!'", Metadata.DefaultLanguage.LanguageCode),
			Object.Metadata().FullName()
		);
		
	EndIf;
	
EndProcedure





