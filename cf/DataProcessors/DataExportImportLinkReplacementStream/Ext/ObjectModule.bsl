#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region LocalVariables

Var CurrentInitialization;
Var CurrentContainer;
Var CurrentHandlers;
Var CurrentReplacementDictionaries;
Var CurrentWeight;

#EndRegion

#Region ServiceProgramInterface

Procedure Initialize(Container, Handlers) Export
	
	If CurrentInitialization Then
		
		Raise NStr("en='The object has already been initialized earlier.';ru='Объект уже был инициализирован ранее!'");
		
	Else
		
		CurrentContainer = Container;
		CurrentHandlers = Handlers;
		CurrentReplacementDictionaries = New Map();
		CurrentWeight = 0;
		
		//
		
		CurrentInitialization = True;
		
	EndIf;
	
EndProcedure

Procedure ReplaceRef(Val XMLTypeName, Val OutdatedIdentifier, Val NewIdentifier) Export
	
	If CurrentReplacementDictionaries.Get(XMLTypeName) = Undefined Then
		CurrentReplacementDictionaries.Insert(XMLTypeName, New Map());
		CurrentWeight = CurrentWeight + 1;
	EndIf;
	
	CurrentReplacementDictionaries.Get(XMLTypeName).Insert(OutdatedIdentifier, NewIdentifier);
	CurrentWeight = CurrentWeight + 1;
	
	If CurrentWeight >= ItemCountUnderRefs() Then
		
		ReplaceRefs();
		CurrentReplacementDictionaries = New Map();
		CurrentWeight = 0;
		
	EndIf;
	
EndProcedure

// Replaces references in the file.
//
// Parameters:
//  FileDescription - ValueTableRow - see variable Content of the object module of the DataExportImportContainerManager handler
//
Procedure ReplaceRefsInFile(Val FileDescription) Export
	
	If CurrentWeight = 0 Then
		Return;
	EndIf;
	
	ReadStream = New TextReader(FileDescription.DescriptionFull);
	
	TempFile = GetTempFileName("xml");
	
	WriteStream = New TextWriter(TempFile);
	
	// Text constants
	TypeBeginning = "xsi:type=""" + RefTypePrefix() + ":";
	TypeBeginningLength = StrLen(TypeBeginning);
	TypeEnd = """>";
	TypeEndLength = StrLen(TypeEnd);
	
	SourceLine = ReadStream.ReadLine();
	While SourceLine <> Undefined Do
		
		RemainingString = Undefined;
		
		CurrentPosition = 1;
		TypePosition = Find(SourceLine, TypeBeginning);
		While TypePosition > 0 Do
			
			WriteStream.Write(Mid(SourceLine, CurrentPosition, TypePosition - 1 + TypeBeginningLength));
			
			RemainingString = Mid(SourceLine, CurrentPosition + TypePosition + TypeBeginningLength - 1);
			CurrentPosition = CurrentPosition + TypePosition + TypeBeginningLength - 1;
			
			TypeEndPosition = Find(RemainingString, TypeEnd);
			If TypeEndPosition = 0 Then
				Break;
			EndIf;
			
			TypeName = Left(RemainingString, TypeEndPosition - 1);
			ReplacementMatching = CurrentReplacementDictionaries.Get(TypeName);
			If ReplacementMatching = Undefined Then
				TypePosition = Find(RemainingString, TypeBeginning);
				Continue;
			EndIf;
			
			WriteStream.Write(TypeName);
			WriteStream.Write(TypeEnd);
			
			SourceRefXML = Mid(RemainingString, TypeEndPosition + TypeEndLength, 36);
			
			FoundRefXML = ReplacementMatching.Get(SourceRefXML);
			
			If FoundRefXML = Undefined Then
				WriteStream.Write(SourceRefXML);
			Else
				WriteStream.Write(FoundRefXML);
			EndIf;
			
			CurrentPosition = CurrentPosition + TypeEndPosition - 1 + TypeEndLength + 36;
			RemainingString = Mid(RemainingString, TypeEndPosition + TypeEndLength + 36);
			TypePosition = Find(RemainingString, TypeBeginning);
			
		EndDo;
		
		If RemainingString <> Undefined Then
			WriteStream.WriteLine(RemainingString);
		Else
			WriteStream.WriteLine(SourceLine);
		EndIf;
		
		SourceLine = ReadStream.ReadLine();
		
	EndDo;
	
	ReadStream.Close();
	WriteStream.Close();
	
	CurrentContainer.ReplaceFile(FileDescription.Name, TempFile);
	
EndProcedure

Procedure Close() Export
	
	ReplaceRefs();
	CurrentContainer = Undefined;
	CurrentReplacementDictionaries = New Map();
	CurrentWeight = 0;
	CurrentInitialization = False;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns a number of
// references according to the matched refs. The number was defined experimentally not to exceed 10 Mb of the random access memory.
//
// Returns:
// Number - number of items.
//
Function ItemCountUnderRefs()
	
	Return 51000;
	
EndFunction

// Replaces references.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// RefReplacementDictionary - Map - see ReplacementDictionary parameter in procedure UpdateRefsMatchingDictionary
//
Procedure ReplaceRefs()
	
	TypesFiles = DataExportImportService.FileTypesThatSupportRefsReplacement();
	
	FileDescriptionFulls = CurrentContainer.GetFileDescriptionsFromDirectory(TypesFiles);
	For Each FileDescription IN FileDescriptionFulls Do
		
		ReplaceRefsInFile(FileDescription);
		
	EndDo;
	
	CurrentHandlers.WhenReplacingReferences(CurrentContainer, CurrentReplacementDictionaries);
	
EndProcedure

Function RefTypePrefix()
	
	NamespacePrefixes = DataExportImportService.NamespacePrefixes();
	Return NamespacePrefixes.Get("http://v8.1c.ru/8.1/data/enterprise/current-config");
	
EndFunction

#EndRegion

CurrentInitialization = False;

#EndIf