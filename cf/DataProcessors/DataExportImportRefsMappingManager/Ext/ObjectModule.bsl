#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ObjectState

Var CurrentContainer;
Var CurrentStreamRefsReplacement;
Var CurrentHandlers;
Var CurrentSourceRefsColumnName;

#EndRegion

#Region ServiceProgramInterface

Procedure Initialize(Container, RefReplacementStream, Handlers) Export
	
	CurrentContainer = Container;
	CurrentStreamRefsReplacement = RefReplacementStream;
	CurrentHandlers = Handlers;
	
	FileName = Container.GetRandomFile(DataExportImportService.DataTypeForValueTableColumnName());
	CurrentSourceRefsColumnName = DataExportImportService.ReadObjectFromFile(FileName);
	
	If CurrentSourceRefsColumnName = Undefined Or IsBlankString(CurrentSourceRefsColumnName) Then 
		Raise NStr("en='Column name with the source reference is not found';ru='Не найдено имя колонки с исходной ссылкой'");
	EndIf;
	
EndProcedure

Procedure MapRefs() Export
	
	FileDescriptionsTable = CurrentContainer.GetFileDescriptionsFromDirectory(DataExportImportService.ReferenceMapping());
	
	Graph = DataProcessors.DataExportImportLinkMatchingDictionaryDependencyGraph.Create();
	
	For Each FileDescription IN FileDescriptionsTable Do
		Graph.AddVertex(FileDescription.DataType);
	EndDo;
	
	TypeDependencies = DataExportImportServiceEvents.GetTypesDependenciesOnReplacingRefs();
	
	For Each TypeDependence IN TypeDependencies Do
		
		If FileDescriptionsTable.FindRows(New Structure("DataType", TypeDependence.Key)).Count() > 0 Then
			
			For Each DependentObjectFullName IN TypeDependence.Value Do
				
				If FileDescriptionsTable.FindRows(New Structure("DataType", DependentObjectFullName)).Count() > 0 Then
					
					Graph.AddRiblet(TypeDependence.Key, DependentObjectFullName);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	TraversalOrder = Graph.TopologicalSort();
	
	For Each MetadataObject IN TraversalOrder Do
		
		FilterParameters = New Structure();
		FilterParameters.Insert("DataType", MetadataObject.FullName());
		RefsMappingDictionaries = FileDescriptionsTable.FindRows(FilterParameters);
		
		For Each FileDescription IN RefsMappingDictionaries Do
			
			// Before reading, replace references in the table of the natural key field values
			CurrentStreamRefsReplacement.ReplaceRefsInFile(FileDescription);
			
			// Read a table with the natural key field values
			SourceRefsTable = DataExportImportService.ReadObjectFromFile(FileDescription.DescriptionFull);
		
			Cancel = False;
			StandardProcessing = True;
			RefsMappingHandler = Undefined;
			
			CurrentHandlers.BeforeMatchRefs(
				CurrentContainer,
				MetadataObject,
				SourceRefsTable,
				StandardProcessing, 
				RefsMappingHandler, 
				Cancel);
			
			If Cancel Then
				Continue;
			EndIf;
			
			If StandardProcessing Then
				
				DataProcessors.DataExportImportRefsMappingManager.StandardRefsMapping(
					CurrentStreamRefsReplacement, MetadataObject, SourceRefsTable, ThisObject);
				
			Else
				
				XMLTypeName = DataExportImportService.XMLReferenceType(MetadataObject);
				
				DictionaryFragment = New Map();
				
				ReferenceMap = RefsMappingHandler.MatchRefs(CurrentContainer, ThisObject, SourceRefsTable);
				For Each MapItem IN ReferenceMap Do
					
					CurrentStreamRefsReplacement.ReplaceRef(XMLTypeName, String(MapItem[CurrentSourceRefsColumnName].UUID()),
						String(MapItem.Ref.UUID()));
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function SourceRefsColumnName() Export
	
	Return CurrentSourceRefsColumnName;
	
EndFunction

#EndRegion

#EndIf
