#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalState

Var CurrentContainer;
Var CurrentSerializer;
Var CurrentRefs;

#EndRegion

#Region ServiceProgramInterface

Procedure Initialize(Container, Serializer) Export
	
	CurrentContainer = Container;
	CurrentSerializer = Serializer;
	
	CurrentRefs = New Array();
	
EndProcedure

Procedure RecreateRefOnImport(Val Refs) Export
	
	CurrentRefs.Add(Refs);
	
	If CurrentRefs.Count() > LinksLimitInFile() Then
		WriteRecreatedRefs();
	EndIf;
	
EndProcedure

Procedure Close() Export
	
	WriteRecreatedRefs();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function LinksLimitInFile()
	
	Return 34000;
	
EndFunction

Procedure WriteRecreatedRefs()
	
	If CurrentRefs.Count() = 0 Then
		Return;
	EndIf;
	
	FileName = CurrentContainer.CreateFile(DataExportImportService.ReferenceRebuilding());
	DataExportImportService.WriteObjectToFile(CurrentRefs, FileName, CurrentSerializer);
	
	CurrentRefs.Clear();
	
EndProcedure

#EndRegion

#EndIf
