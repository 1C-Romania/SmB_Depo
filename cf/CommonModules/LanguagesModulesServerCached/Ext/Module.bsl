Function GetSystemLanguage() Export
	Return Constants.NationalLanguage.Get();
EndFunction

Function GetPresentationLanguage(Val DataRef) Export
	Presentation = "";
	If Not SessionParameters.CurrentLanguage = LanguagesModulesServerCached.GetSystemLanguage() Then
		LanguagesRows = DataRef.LanguagesDescription.FindRows(New Structure("Language", SessionParameters.CurrentLanguage));
		If LanguagesRows.Count() > 0 Then
			Presentation = TrimAll(LanguagesRows[0].Description);
		EndIf;
	EndIf;
	Return Presentation;
EndFunction
