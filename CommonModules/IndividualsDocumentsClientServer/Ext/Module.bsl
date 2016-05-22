
////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns the series type of the identity document
//
// Parameters:
// DocumentKind - Catalog.IndividualsDocumentsKinds
//
// Returns:
// Number	- the series type for the document, 0 - There are no requirements for the series
//
Function DocumentSeriesTypeIdentifiedPerson(DocumentKind) Export
	
	DocumentType = 0;
	If DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.OldPassport")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.BirthCertificate") Then
		DocumentType = 1;
		
	ElsIf DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.OfficerIdentity")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.LocalSeamanBook")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.MilitaryCard")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.SeamanBook")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.ReserveOfficerMilitaryCard") Then
		DocumentType = 2;
		
	ElsIf DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.OldForeignPassport")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.DiplomaticPassport")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.ForeignPassport") Then
		DocumentType = 3;
		
	ElsIf DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.LocalPassport") Then
		DocumentType = 4;
		
	EndIf;
	
	Return DocumentType;
	
EndFunction

// Returns the number type of the identity document
//
// Parameters:
// DocumentKind - Catalog.IndividualsDocumentsKinds
//
// Returns:
// Number	- the number type for the document, 0 - There are no requirements for the number
//
Function DocumentIdentifiedPersonTypeNumber(DocumentKind) Export
	
	DocumentType = 0;
	If DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.OldPassport")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.BirthCertificate")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.OfficerIdentity")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.LocalSeamanBook")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.LocalPassport") Then
		DocumentType = 1;
		
	ElsIf DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.DiplomaticPassport")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.ForeignPassport") Then
		DocumentType = 2;
		
	ElsIf DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.OldForeignPassport")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.MilitaryCard")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.SeamanBook")
		Or DocumentKind = PredefinedValue("Catalog.IndividualsDocumentsKinds.ReserveOfficerMilitaryCard") Then
		DocumentType = 3;
		
	EndIf;
	
	Return DocumentType;
	
EndFunction

// Checks that the document series for the passed document kind specified correctly.
//
// Parameters:
// DocumentKind - CatalogRef.IndividualsDocumentsKinds	- the document kind for
// 															which it is
// necessary to verify the correctness of the series Series - String												- the
// document series ErrorText - String										- the text of the error if the specified series is wrong
//
// Returns:
// Boolean - the verification result, true - correctly, false - no.
//
Function DocumentSeriesSpecifiedProperly(DocumentKind, Val Series , ErrorText) Export
	
	DocumentType = DocumentSeriesTypeIdentifiedPerson(DocumentKind);
	
	Series = TrimAll(Series);
	
	If DocumentType = 1 Then // a USSR passport and a birth certificate
		
		Pos = Find(Series, "-");
		If Pos = 0 Then
			ErrorText = NStr("en = 'The document series must consist of two parts, separated by ""-"".'");
			Return False;
		EndIf;
		
		SeriesPart1 = Left(Series, Pos - 1);
		SeriesPart2 = TrimAll(Mid(Series, Pos + 1));
		
		Pos = Find(SeriesPart2, "-");
		If Pos <> 0 Then
			ErrorText = NStr("en = 'The document series must contain only two symbol groups.'");
			Return False;
		EndIf;
		
		If IsBlankString(SeriesPart1) Then
			ErrorText = NStr("en = 'The document series has no numeric part.'");
			Return False;
			
		ElsIf  IsBlankString(StringFunctionsClientServer.ReplaceSomeCharactersWithAnothers("IVXLC", SeriesPart1, "          ")) = 0 Then
			ErrorText = NStr("en = 'Numerical part of a document series must be specified by the following symbols I V X L C.'");
			Return False;
			
		ElsIf StringFunctionsClientServer.ReplaceSomeCharactersWithAnothers("IVXLC", SeriesPart1, "IVXLC") <> StringFunctionsClientServer.ConvertNumberToRomanNumeral(StringFunctionsClientServer.ConvertDigitToArabicNumeral(StringFunctionsClientServer.ReplaceSomeCharactersWithAnothers("IVXLC", SeriesPart1, "IVXLC"))) Then
			ErrorText = NStr("en = 'Numerical part of the document series is specified incorrectly.'");
			Return False;
			
		ElsIf StrLen(SeriesPart2) <> 2 Or Not IsBlankString(StringFunctionsClientServer.ReplaceSomeCharactersWithAnothers("ABCDEFGHIJKLMNOPQRSTUVWXYZ", SeriesPart2, "                                 ")) Then
			ErrorText = NStr("en = 'After the separator ""-"" in the document series must be TWO Russian capital letters.'");
			Return False;
			
		EndIf;
		
	ElsIf DocumentType = 2 Then // Series - two letters: military service card, ...
		If StrLen(Series) <> 2 Or Not IsBlankString(StringFunctionsClientServer.ReplaceSomeCharactersWithAnothers("ABCDEFGHIJKLMNOPQRSTUVWXYZ", Series, "                                 ")) Then
			ErrorText = NStr("en = 'the document series must contain TWO russian capital letters.'");
			Return False;
		EndIf;
		
	ElsIf DocumentType = 3 Then // Series - two figures: international passport
		If StrLen(Series) <> 2 Or Not IsBlankString(StringFunctionsClientServer.ReplaceSomeCharactersWithAnothers("0123456789", Series, "          ")) Then
			ErrorText = NStr("en = 'Document series must contain only TWO digits.'");
			Return False;
		EndIf;
		
	ElsIf DocumentType = 4 Then // Series - two groups of figures: new passport
		Pos = Find(Series, " ");
		If Pos = 0 Then
			ErrorText = NStr("en = 'Document series must contain two digit groups.'");
			Return False;
		EndIf;
		
		FirstPart = Left(Series, Pos-1);
		SecondPart = TrimAll(Mid(Series, Pos+1));
		
		Pos = Find(SecondPart, " ");
		If Pos <> 0 Then
			ErrorText = NStr("en = 'Document series must have only two digit groups.'");
			Return False;
		EndIf;
		
		If StrLen(FirstPart) <> 2 Or Not IsBlankString(StringFunctionsClientServer.ReplaceSomeCharactersWithAnothers("0123456789", FirstPart, "          ")) Then
			ErrorText = NStr("en = 'First group of the document series symbols must contain two digits.'");
			Return False;
		EndIf;
		
		If StrLen(SecondPart) <> 2 Or Not IsBlankString(StringFunctionsClientServer.ReplaceSomeCharactersWithAnothers("0123456789", SecondPart, "          ")) Then
			ErrorText = NStr("en = 'Second group of the document series symbols must contain two digits.'");
			Return False;
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

// Checks that the document number for the passed document kind specified correctly.
//
// Parameters:
// DocumentKind - CatalogRef.IndividualsDocumentsKinds	- the document kind for
// 															which it is
// necessary to verify the correctness of the number Number - String												- the
// document number ErrorText - String										- the text of the error if the specified number is wrong
//
// Returns:
// Boolean - the verification result, true - correctly, false - no.
//
Function DocumentNumberSpecifiedProperly(DocumentKind, Val Number, ErrorText) Export
	
	If Not IsBlankString(StringFunctionsClientServer.ReplaceSomeCharactersWithAnothers("0123456789", Number, "          ")) Then
		ErrorText = NStr("en = 'Invalid symbols are present in the document number.'");
		Return False;
	EndIf;
	
	DocumentType = DocumentIdentifiedPersonTypeNumber(DocumentKind);
	
	NumberLength = StrLen(TrimAll(Number));
	
	If DocumentType = 1 Then
		If NumberLength <> 6 Then
			ErrorText = NStr("en = 'The document number must consist of 6 symbols.'");
			Return False;
		EndIf;
		
	ElsIf DocumentType = 2 Then
		If NumberLength <> 7 Then
			ErrorText = NStr("en = 'The document number must consist of 7 symbols.'");
			Return False;
		EndIf;
		
	ElsIf DocumentType = 3 Then
		If (NumberLength < 6 ) Or ( NumberLength > 7 ) Then
			ErrorText = NStr("en = 'Document number must consist of 6 or 7 symbols.'");
			Return False;
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction
