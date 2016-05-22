#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ObjectState

Var CurrentContainer;
Var CurrentStreamRefsReplacement;

#EndRegion

#Region ServiceProgramInterface

Procedure Initialize(Container, RefReplacementStream) Export
	
	CurrentContainer = Container;
	CurrentStreamRefsReplacement = RefReplacementStream;
	
EndProcedure

Procedure RecreateRefs() Export
	
	FilesRecreatedRefs = CurrentContainer.GetFilesFromDirectory(DataExportImportService.ReferenceRebuilding());
	For Each FileRecreatedRefs IN FilesRecreatedRefs Do
		
		SourceRefs = DataExportImportService.ReadObjectFromFile(FileRecreatedRefs);
		
		For Each SourceRef IN SourceRefs Do
			
			XMLTypeName = DataExportImportService.XMLReferenceType(SourceRef);
			NewRef = ServiceTechnologyIntegrationWithSSL.ObjectManagerByFullName(SourceRef.Metadata().FullName()).GetRef();
			
			CurrentStreamRefsReplacement.ReplaceRef(XMLTypeName,
				String(SourceRef.UUID()),
				String(NewRef.UUID())
			);
			
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
