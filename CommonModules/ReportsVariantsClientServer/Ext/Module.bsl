////////////////////////////////////////////////////////////////////////////////
// Subsystem "Variants of reports" (client, server).
// 
// Ecxecuted on client and server.
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Presentation of the subsystem. Used when recording into the event log and in other places.
Function SubsystemDescription(LanguageCode) Export
	Return NStr("en = 'Reports variants'", ?(LanguageCode = Undefined, CommonUseClientServer.MainLanguageCode(), LanguageCode));
EndFunction

// Presentation of the importance group.
Function PresentationSeeAlso() Export
	Return NStr("en = 'See also'");
EndFunction 

// Presentation of the importance group.
Function PresentationImportant() Export
	Return NStr("en = 'Important'");
EndFunction

// Name of the notification event for changing the report variant.
Function EventNameOptionChanging() Export
	Return SubsystemFullName() + ".OptionChanging";
EndFunction

// Full name of the subsystem.
Function SubsystemFullName() Export
	Return "StandardSubsystems.ReportsVariants";
EndFunction

// Delimiter that is used when storing several items in one string attribute.
Function StorageDelimiter() Export
	Return Chars.LF;
EndFunction

// Delimiter that is used to display some items in the interface.
Function SeparatorPresentation() Export
	Return ", ";
EndFunction

// Converts a search string into words array with unique values and sorted by descending length.
Function DecomposeSearchStringIntoWordsArray(SearchString) Export
	WordsAndTheirLength = New ValueList;
	StringLength = StrLen(SearchString);
	
	Word = "";
	WordLength = 0;
	QuoteIsOpen = False;
	For CharacterNumber = 1 To StringLength Do
		CharCode = CharCode(SearchString, CharacterNumber);
		If CharCode = 34 Then // 34 - double quote "".
			QuoteIsOpen = Not QuoteIsOpen;
		ElsIf QuoteIsOpen
			Or (CharCode >= 48 AND CharCode <= 57) // Digits
			Or (CharCode >= 65 AND CharCode <= 90) // upper case Latin characters
			Or (CharCode >= 97 AND CharCode <= 122) // lower case Latin characters
			Or (CharCode >= 1040 AND CharCode <= 1103) // Cyrillic alphabet
			Or CharCode = 95 Then // Character "_"
			Word = Word + Char(CharCode);
			WordLength = WordLength + 1;
		ElsIf Word <> "" Then
			If WordsAndTheirLength.FindByValue(Word) = Undefined Then
				WordsAndTheirLength.Add(Word, Format(WordLength, "ND=3; NLZ="));
			EndIf;
			Word = "";
			WordLength = 0;
		EndIf;
	EndDo;
	
	If Word <> "" AND WordsAndTheirLength.FindByValue(Word) = Undefined Then
		WordsAndTheirLength.Add(Word, Format(WordLength, "ND=3; NLZ="));
	EndIf;
	
	WordsAndTheirLength.SortByPresentation(SortDirection.Desc);
	
	Return WordsAndTheirLength.UnloadValues();
EndFunction

#EndRegion
