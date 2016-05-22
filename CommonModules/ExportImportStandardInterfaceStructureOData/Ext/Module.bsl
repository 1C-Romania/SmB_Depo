#Region ServiceProgramInterface

Procedure WhenDataImportHandlersRegistration(HandlersTable) Export
	
	NewHandler = HandlersTable.Add();
	NewHandler.Handler = ExportImportStandardInterfaceStructureOData;
	NewHandler.BeforeDataExport = True;
	NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
	
EndProcedure

Procedure BeforeDataExport(Container) Export
	
	If CommonUseSTLReUse.AvailableMechanismsCompatibilityMode8_3_5() Then
		
		Content = WorkInSafeMode.EvalInSafeMode("GetStandardInterfaceContent()");
		SerializedContent = New Array();
		
		For Each ContentItem IN Content Do
			
			SerializedContent.Add(ContentItem.FullName());
			
		EndDo;
		
		FileName = Container.CreateRandomFile("xml", DataTypeForStandardInterfaceContentOData());
		DataExportImportService.WriteObjectToFile(SerializedContent, FileName);
		
	EndIf;
	
EndProcedure

Procedure WhenDataExportHandlersRegistration(HandlersTable) Export
	
	NewHandler = HandlersTable.Add();
	NewHandler.Handler = ExportImportStandardInterfaceStructureOData;
	NewHandler.BeforeDataImport = True;
	NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
	
EndProcedure

Procedure BeforeDataImport(Container) Export
	
	If CommonUseSTLReUse.AvailableMechanismsCompatibilityMode8_3_5() Then
		
		FileName = Container.GetRandomFile(DataTypeForStandardInterfaceContentOData());
		Content = DataExportImportService.ReadObjectFromFile(FileName);
		
		If Content.Count() > 0 Then
			
			WorkInSafeMode.ExecuteInSafeMode("SetStandardInterfaceContentOData(Parameters)", Content);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function DataTypeForStandardInterfaceContentOData()
	
	Return "StandardODataInterfaceContent"; // Not localized
	
EndFunction

#EndRegion
