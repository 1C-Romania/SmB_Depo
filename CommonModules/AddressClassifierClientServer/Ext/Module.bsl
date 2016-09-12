////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Subsystem "Address classifier".
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

//  Name of the event for writing to the events log monitor.
//
Function EventLogMonitorEvent() Export
	
	Return NStr("en='Address classifier';ru='Адресный классификатор'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Separate the source text into the full name and abbreviation.
// Abbreviation is considered to be the last word, separated by whitespace.
//
// Parameters:
//     Description - String - Full name, for example "Moscow".
//
// Returns:
//     Structure - contain fields.
//       * Description - String - Name, for example "Moscow". If abbreviation is can not be
//                                 allocated, then the original name.
//       * Abbreviation   - String - Abbreviation, for example "g". If abbreviation can not be allocated, then there is an empty string.
//
Function DescriptionAndAbbreviation(Description) Export
	SearchText = TrimR(Description);
	
	Position = StrLen(SearchText);
	While Position > 0 Do
		If IsBlankString(Mid(SearchText, Position, 1)) Then
			Break;
		EndIf;
		Position = Position - 1;
	EndDo;
	
	Result = New Structure("Description, Abbr");
	If Position = 0 Then
		Result.Description = SearchText;
		Result.Abbr   = "";
	Else
		Result.Description = TrimR(Left(SearchText, Position));
		Result.Abbr   = Mid(SearchText, Position + 1);
	EndIf;
	
	Return Result;
EndFunction

// The set of levels for queries in compatibility mode with KLADR.
//
// Returns:
//     FixedArray - the set of numeric levels.
//
Function AddressClassifierLevels() Export
	
	Levels = New Array;
	Levels.Add(1);
	Levels.Add(3);
	Levels.Add(4);
	Levels.Add(6);
	Levels.Add(7);
	
	Return New FixedArray(Levels);
EndFunction

// The set of levels for FIAS queries.
//
// Returns:
//     FixedArray - the set of numeric levels.
//
Function FIASClassifierLevels() Export
	
	Levels = New Array;
	Levels.Add(1);
	Levels.Add(2);
	Levels.Add(3);
	Levels.Add(5);
	Levels.Add(4);
	Levels.Add(6);
	Levels.Add(7);
	Levels.Add(90);
	Levels.Add(91);
	
	Return New FixedArray(Levels);
EndFunction

#EndRegion