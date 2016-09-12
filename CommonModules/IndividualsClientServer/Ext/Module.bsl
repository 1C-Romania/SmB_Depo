////////////////////////////////////////////////////////////////////////////////
// Subsystem "Individuals".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Function decomposes Initials into structure.
//
// Parameters:
//  Initials - String - name.
//
// Returns:
//  Structure - with properties: 
//     * Last name    - String
//     * Name       - String
//     * Patronymic - String
//
Function LastNameNamePatronymic(Val Initials) Export
	
	StructureSNP = New Structure("Last name, Name, Patronymic");
	
	SubstringArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Initials, " ");
	
	If SubstringArray.Count() > 0 Then
		StructureSNP.Insert("Surname", SubstringArray[0]);
		If SubstringArray.Count() > 1 Then
			StructureSNP.Insert("Name", SubstringArray[1]);
		EndIf;
		If SubstringArray.Count() > 2 Then
			Patronymic = "";
			For Step = 2 To SubstringArray.Count()-1 Do
				Patronymic = Patronymic + SubstringArray[Step] + " ";
			EndDo;
			StringFunctionsClientServer.DeleteLatestCharInRow(Patronymic, 1);
			StructureSNP.Insert("Patronymic", Patronymic);
		EndIf;
	EndIf;
	
	Return StructureSNP;
	
EndFunction

// Generates a last name and initials by passed strings.
//
// Parameters:
//  InitialsString	- String - if this parameter is specified, then others are ignored.
//  Surname		- String - individual's last name.
//  Name			- String - individual's name.
//  Patronymic	- String - individual's patronymic.
//
// Returns:
//  String - last name and initials in one string. 
//  Calculated parts are written to parameters Last name, Name, and Patronymic.
//
// Example:
//  Result = SurnameInitialsOfIndividual("Ivanov Ivan Ivanovich"//);  Result = "Ivanov I. I."
//
Function SurnameInitialsOfIndividual(InitialsString = "", Surname = " ", Name = " ", Patronymic = " ") Export

	ObjectType = TypeOf(InitialsString);
	If ObjectType = Type("String") Then
		Initials = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(TrimAll(InitialsString), " ");
		
	Else
		// Use other strings that are possibly passed.
		Return ?(NOT IsBlankString(Surname), 
		          Surname + ?(NOT IsBlankString(Name), " " + Left(Name,1) + "." + ?(NOT IsBlankString(Patronymic), Left(Patronymic,1) + ".", ""), ""),
		          "");
	EndIf;
	
	CountSubstrings = Initials.Count();
	Surname            = ?(CountSubstrings > 0, Initials[0], "");
	Name                = ?(CountSubstrings > 1, Initials[1], "");
	Patronymic           = ?(CountSubstrings > 2, Initials[2], "");
	
	If CountSubstrings > 3 Then
		AdditionalPatronymicParts = New Array;
		AdditionalPatronymicParts.Add(NStr("en='oglu';ru='оглы'"));
		AdditionalPatronymicParts.Add(NStr("en='uly';ru='улы'"));
		AdditionalPatronymicParts.Add(NStr("en='uulu';ru='уулу'"));
		AdditionalPatronymicParts.Add(NStr("en='kyzy';ru='кызы'"));
		AdditionalPatronymicParts.Add(NStr("en='gizi';ru='гызы'"));
		
		If AdditionalPatronymicParts.Find(Lower(Initials[3])) <> Undefined Then
			Patronymic = Patronymic + " " + Initials[3];
		EndIf;
	EndIf;
	
	Return ?(NOT IsBlankString(Surname), 
	          Surname + ?(NOT IsBlankString(Name), " " + Left(Name, 1) + "." + ?(NOT IsBlankString(Patronymic), Left(Patronymic, 1) + ".", ""), ""),
	          "");
	
EndFunction

// Checks whether initials are written correctly.
// Initials can be written either in cyrillic or latin.
// You can also specify that initials are only correct in cyrillic.
//
// Parameters:
// 	RowParameter - String - Initials.
// 	ValidOnlyCyrillic - if True, then the initials are checked to be written in cyrillic, latin is an error in this case.
// 								False - Initials are written correctly if they are written either in latin or cyrillic.
//
// Returns:
// 	True - Initials are written correctly, otherwise, False.
//
Function DescriptionFullIsTrue(Val RowParameter, OnlyCyrillic = False) Export
	
	AllowedChars = "-";
	
	Return (NOT OnlyCyrillic AND StringFunctionsClientServer.OnlyRomanInString(RowParameter, False, AllowedChars)) Or
			StringFunctionsClientServer.OnlyLatinInString(RowParameter, False, AllowedChars);
	
EndFunction

// Outdated. It is recommended to use function of CommonUse.Decline.
// The function does not operate in the client.
Function Decline(Val Initials, Case, Result, Gender = Undefined) Export
	#If Server Then
	Return CommonUse.Decline(Initials, Case, Result, Gender);
	#Else
	Result = Initials;
	Return False;
	#EndIf
EndFunction

#EndRegion
