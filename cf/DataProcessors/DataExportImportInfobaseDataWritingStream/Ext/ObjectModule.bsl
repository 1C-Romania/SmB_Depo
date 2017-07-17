#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region LocalVariables

Var CurrentInitialization;
Var CurrentWriteStream;
Var CurrentObjectsCounter;
Var CurrentSerializer;

#EndRegion

#Region ServiceProgramInterface

Procedure OpenFile(Val FileName, Val Serializer = Undefined) Export
	
	If CurrentInitialization Then
		
		Raise NStr("en='The object has already been initialized earlier.';ru='Объект уже был инициализирован ранее!'");
		
	Else
		
		If Serializer = Undefined Then
			CurrentSerializer = XDTOSerializer;
		Else
			CurrentSerializer = Serializer;
		EndIf;
		
		CurrentWriteStream = New XMLWriter();
		CurrentWriteStream.OpenFile(FileName);
		CurrentWriteStream.WriteXMLDeclaration();
		
		CurrentWriteStream.WriteStartElement("Data");
		
		NamespacePrefixes = DataExportImportService.NamespacePrefixes();
		For Each NamespacePrefix IN NamespacePrefixes Do
			CurrentWriteStream.WriteNamespaceMapping(NamespacePrefix.Value, NamespacePrefix.Key);
		EndDo;
		
		CurrentObjectsCounter = 0;
		
		//
		
		CurrentInitialization = True;
		
	EndIf;
	
EndProcedure

Procedure WriteInfobaseDataObject(Object, Artifacts) Export
	
	CurrentWriteStream.WriteStartElement("DumpElement");
	
	If Artifacts.Count() > 0 Then
		
		CurrentWriteStream.WriteStartElement("Artefacts");
		For Each Artifact in Artifacts Do 
			
			XDTOFactory.WriteXML(CurrentWriteStream, Artifact);
			
		EndDo;
		CurrentWriteStream.WriteEndElement();
		
	EndIf;
	
	Try
		
		CurrentSerializer.WriteXML(CurrentWriteStream, Object);
		
	Except
		
		ErrorInitialText = DetailErrorDescription(ErrorInfo());
		InitialErrorTextWithoutInvalidCharacters = CommonUseClientServer.ReplaceInadmissibleCharsXML(
			ErrorInitialText,
			Char(65533)
		);
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='An error occurred when exporting object %1: %2';ru='При выгрузке объекта %1 произошла ошибка: %2'"),
			Object,
			InitialErrorTextWithoutInvalidCharacters
		);
		
	EndTry;
	
	CurrentWriteStream.WriteEndElement();
	
	CurrentObjectsCounter = CurrentObjectsCounter + 1;
	
EndProcedure

Function ObjectCount() Export
	
	Return CurrentObjectsCounter;
	
EndFunction

Procedure Close() Export
	
	CurrentWriteStream.WriteEndElement();
	CurrentWriteStream.Close();
	
EndProcedure

#EndRegion

CurrentInitialization = False;

#EndIf