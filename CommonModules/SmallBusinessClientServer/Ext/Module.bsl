
//Procedure checks whether TIN and KPP
//are entered correctly Takes
//the Pass parameters structure - the
// Mandatory keys structure
//	of
//	the
//	structure
//	TIN
//	KPP
// IsLegalEntity NoTINErrors NoKPPErrors
//	Additional keys of the IncorrectValueHighlightColor structure
//
//Returns a structure with variable set of keys only with the values corresponding to the check result.
Function CheckTINKPPCorrectness(Val ParametersStructure) Export
	
	If ParametersStructure.Property("ColorHighlightIncorrectValues") Then
		ColorHighlightIncorrectValues = ParametersStructure.ColorHighlightIncorrectValues;
	Else
		ColorHighlightIncorrectValues = New Color(225, 40, 40);
	EndIf;
	
	ReturnStructure = New Structure;
	
	//( elmi
	IsNotRussianCompany = False;
	If ParametersStructure.Property("IsNotRussianCompany", IsNotRussianCompany) and IsNotRussianCompany Then
		If ParametersStructure.CheckTIN Then
		
			ReturnStructure.Insert("TINEnteredCorrectly",               True);
			ReturnStructure.Insert("ExtendedTINPresentation",      		ParametersStructure.TIN);
			ReturnStructure.Insert("LabelExplanationsOfIncorrectTIN", 	"");
			ReturnStructure.Insert("EmptyTIN",                        	False);
			ReturnStructure.Insert("NoErrorsByTIN",                   	ParametersStructure.CheckTIN);
			
		EndIf;
		
		If ParametersStructure.CheckKPP Then
			
			ReturnStructure.Insert("KPPEnteredCorrectly",               True);
			ReturnStructure.Insert("ExtendedKPPPresentation",      		ParametersStructure.KPP);
			ReturnStructure.Insert("LabelExplanationsOfIncorrectKPP", 	"");
			ReturnStructure.Insert("EmptyKPP",                        	False);
			ReturnStructure.Insert("NoErrorsByKPP",                   	ParametersStructure.CheckKPP);
		
		EndIf;
		
		Return ReturnStructure;
		
	EndIf;
	//) elmi	
	
	If ParametersStructure.CheckTIN Then
		
		ReturnStructure.Insert("TINEnteredCorrectly",               True);
		ReturnStructure.Insert("ExtendedTINPresentation",      ParametersStructure.TIN);
		ReturnStructure.Insert("LabelExplanationsOfIncorrectTIN", "");
		ReturnStructure.Insert("EmptyTIN",                        False);
		ReturnStructure.Insert("NoErrorsByTIN",                   ParametersStructure.CheckTIN);
		
		TIN      = TrimR(ParametersStructure.TIN);
		TINLength = StrLen(TIN);
		
		If Not ValueIsFilled(TIN) Then
			
			ReturnStructure.TINEnteredCorrectly = False;
			
			ReturnStructure.LabelExplanationsOfIncorrectTIN = Undefined;
			
			ReturnStructure.EmptyTIN = True;
			
			ReturnStructure.NoErrorsByTIN = False;
			
		EndIf;
		
		If ReturnStructure.NoErrorsByTIN Then
			
			ThisIsLegalEntity = Undefined;
			ParametersStructure.Property("ThisIsLegalEntity", ThisIsLegalEntity);
			
			If ThisIsLegalEntity = Undefined Then
				
				ReturnStructure.TINEnteredCorrectly = False;
				ReturnStructure.LabelExplanationsOfIncorrectTIN = New FormattedString(NStr("en='Unknown counterparty kind. Specify counterparty kind';ru='Неизвестен вид контрагента. Укажите вид контрагента'"),,ColorHighlightIncorrectValues);
				
				ReturnStructure.NoErrorsByTIN = False;
				
			EndIf;
			
			If ReturnStructure.NoErrorsByTIN Then
				
				If  ThisIsLegalEntity AND TINLength <> 10 Then
					
					ReturnStructure.TINEnteredCorrectly = False;
					
					ReturnStructure.LabelExplanationsOfIncorrectTIN = New FormattedString(NStr("en='TIN of legal entity should consist of 10 digits';ru='ИНН юридического лица должен состоять из 10 цифр'"),,ColorHighlightIncorrectValues);
					
					TextForIncorrectTIN = NStr("en='%
		|TIN does not contain 10 digits';ru='%1
		|ИНН содержит не 10 цифр'");
					
					ReturnStructure.ExtendedTINPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectTIN, TIN);
					
					ReturnStructure.NoErrorsByTIN = False;
					
				ElsIf Not ThisIsLegalEntity  AND TINLength <> 12 Then
					
					ReturnStructure.TINEnteredCorrectly = False;
					
					ReturnStructure.LabelExplanationsOfIncorrectTIN = New FormattedString(NStr("en='Individual’s TIN should consist of 12 digits.';ru='ИНН физического лица должен состоять из 12 цифр'"),,ColorHighlightIncorrectValues);
					
					TextForIncorrectTIN = NStr("en='%
		|TIN does not contain 12 digits';ru='%1
		|ИНН содержит не 12 цифр'");
					
					ReturnStructure.ExtendedTINPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectTIN, TIN);
					
					ReturnStructure.NoErrorsByTIN = False;
					
				ElsIf Left(TIN, 2) = "00" Then
					
					ReturnStructure.TINEnteredCorrectly = False;
					
					ReturnStructure.LabelExplanationsOfIncorrectTIN = New FormattedString(NStr("en='The first two TIN digits can not be ""00""';ru='Первые две цифры ИНН не могут быть ""00""'"),,ColorHighlightIncorrectValues);
					
					TextForIncorrectTIN = NStr("en='%1
		|The first two TIN digits can not be ""00""';ru='%1
		|Первые две цифры ИНН не могут быть ""00""'");
					
					ReturnStructure.ExtendedTINPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectTIN, TIN);
					
					ReturnStructure.NoErrorsByTIN = False;
					
				EndIf;
				
				If ReturnStructure.NoErrorsByTIN Then
					
					If Not StringFunctionsClientServer.OnlyNumbersInString(TIN) Then
						
						ReturnStructure.TINEnteredCorrectly = False;
						
						ReturnStructure.LabelExplanationsOfIncorrectTIN = New FormattedString(NStr("en='TIN should include only digits';ru='ИНН должен включать только цифры'"),,ColorHighlightIncorrectValues);
						
						TextForIncorrectTIN = NStr("en='%
		|TIN includes not only digits';ru='%1
		|ИНН содержит не только цифры'");
						
						ReturnStructure.ExtendedTINPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectTIN, TIN);
						
						ReturnStructure.NoErrorsByTIN = False;
						
					EndIf;
					
					If ReturnStructure.NoErrorsByTIN Then
						
						If ThisIsLegalEntity Then
							
							CheckSum = 0;
							
							For N = 1 To 9 Do
								
								If N = 1 Then
									Factor = 2;
								ElsIf N = 2 Then
									Factor = 4;
								ElsIf N = 3 Then
									Factor = 10;
								ElsIf N = 4 Then
									Factor = 3;
								ElsIf N = 5 Then
									Factor = 5;
								ElsIf N = 6 Then
									Factor = 9;
								ElsIf N = 7 Then
									Factor = 4;
								ElsIf N = 8 Then
									Factor = 6;
								ElsIf N = 9 Then
									Factor = 8;
								EndIf;
								
								Digit = Number(Mid(TIN, N, 1));
								CheckSum = CheckSum + Digit * Factor;
								
							EndDo;
							
							CheckDigit = (CheckSum %11) %10;
							
							If CheckDigit <> Number(Mid(TIN, 10, 1)) or CheckSum = 0 Then
								
								ReturnStructure.TINEnteredCorrectly = False;
								
								ReturnStructure.LabelExplanationsOfIncorrectTIN = New FormattedString(NStr("en=""Legal entity's TIN is incorrect"";ru='ИНН юридического лица введен некорректно'"),,ColorHighlightIncorrectValues);
								
								TextForIncorrectTIN = NStr("en='%1
		|TIN does not correspond to the format';ru='%1
		|ИНН не соответствует формату'");
								
								ReturnStructure.ExtendedTINPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectTIN, TIN);
								
								ReturnStructure.NoErrorsByTIN = False;
								
							EndIf;
							
						Else
							
							CheckSum11 = 0;
							CheckSum12 = 0;
							
							For N=1 To 11 Do
								
								// Calculation of multipliers for 11th and 12th digits
								If N = 1 Then
									Factor11 = 7;
									Factor12 = 3;
								ElsIf N = 2 Then
									Factor11 = 2;
									Factor12 = 7;
								ElsIf N = 3 Then
									Factor11 = 4;
									Factor12 = 2;
								ElsIf N = 4 Then
									Factor11 = 10;
									Factor12 = 4;
								ElsIf N = 5 Then
									Factor11 = 3;
									Factor12 = 10;
								ElsIf N = 6 Then
									Factor11 = 5;
									Factor12 = 3;
								ElsIf N = 7 Then
									Factor11 = 9;
									Factor12 = 5;
								ElsIf N = 8 Then
									Factor11 = 4;
									Factor12 = 9;
								ElsIf N = 9 Then
									Factor11 = 6;
									Factor12 = 4;
								ElsIf N = 10 Then
									Factor11 = 8;
									Factor12 = 6;
								ElsIf N = 11 Then
									Factor11 = 0;
									Factor12 = 8;
								EndIf;
								
								Digit = Number(Mid(TIN, N, 1));
								CheckSum11 = CheckSum11 + Digit * Factor11;
								CheckSum12 = CheckSum12 + Digit * Factor12;
								
							EndDo;
							
							CheckDigit11 = (CheckSum11 %11) %10;
							CheckDigit12 = (CheckSum12 %11) %10;
							
							If CheckDigit11 <> Number(Mid(TIN,11,1)) OR CheckDigit12 <> Number(Mid(TIN,12,1)) or (CheckSum11 = 0 and CheckSum12 = 0) Then
								
								ReturnStructure.TINEnteredCorrectly = False;
								
								ReturnStructure.LabelExplanationsOfIncorrectTIN = New FormattedString(NStr("en=""Individual's TIN is incorrect"";ru='ИНН физического лица введен некорректно'"),,ColorHighlightIncorrectValues);
								
								TextForIncorrectTIN = NStr("en='%1
		|TIN does not correspond to the format';ru='%1
		|ИНН не соответствует формату'");
								
								ReturnStructure.ExtendedTINPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectTIN, TIN);
								
								ReturnStructure.NoErrorsByTIN = False;
								
							EndIf;
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If ParametersStructure.CheckKPP Then
		
		ReturnStructure.Insert("KPPEnteredCorrectly",               True);
		ReturnStructure.Insert("ExtendedKPPPresentation",      ParametersStructure.KPP);
		ReturnStructure.Insert("LabelExplanationsOfIncorrectKPP", "");
		ReturnStructure.Insert("EmptyKPP",                        False);
		ReturnStructure.Insert("NoErrorsByKPP",                   ParametersStructure.CheckKPP);
		
		ThisIsLegalEntity = Undefined;
		ParametersStructure.Property("ThisIsLegalEntity", ThisIsLegalEntity);
		
		If ThisIsLegalEntity = Undefined Then
			
			ReturnStructure.KPPEnteredCorrectly = False;
			
			ReturnStructure.LabelExplanationsOfIncorrectKPP = New FormattedString(NStr("en='Unknown counterparty kind. Specify counterparty kind';ru='Неизвестен вид контрагента. Укажите вид контрагента'"),,ColorHighlightIncorrectValues);
			
			ReturnStructure.NoErrorsByKPP = False;
			
		ElsIf Not ThisIsLegalEntity Then
			ReturnStructure.NoErrorsByKPP = False;
		EndIf;
		
		If ReturnStructure.NoErrorsByKPP Then
			
			KPP = TrimR(ParametersStructure.KPP);
			KPPLength = StrLen(KPP);
			
			If Not ValueIsFilled(KPP) Then
				
				ReturnStructure.KPPEnteredCorrectly = False;
				
				ReturnStructure.LabelExplanationsOfIncorrectKPP = Undefined;
				
				ReturnStructure.EmptyKPP = True;
				
				ReturnStructure.NoErrorsByKPP = False;
				
			EndIf;
			
			If ReturnStructure.NoErrorsByKPP Then
				
				If KPPLength <> 9 Then
					
					ReturnStructure.KPPEnteredCorrectly = False;
					
					ReturnStructure.LabelExplanationsOfIncorrectKPP  = New FormattedString(NStr("en='KPP should contain 9 digits';ru='""КПП"" должен содержать 9 цифр'"),,ColorHighlightIncorrectValues);
					
					TextForIncorrectKPP = NStr("en='&1
		|KPP does not contain 9 digits';ru='%1
		|КПП содержит не 9 цифр'");
					
					ReturnStructure.ExtendedKPPPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectKPP, KPP);
					
					ReturnStructure.NoErrorsByKPP = False;
					
				EndIf;
				
				If ReturnStructure.NoErrorsByKPP Then
					
					If Not StringFunctionsClientServer.OnlyNumbersInString(KPP) Then
						
						ReturnStructure.KPPEnteredCorrectly = False;
						
						ReturnStructure.LabelExplanationsOfIncorrectKPP = New FormattedString(NStr("en='KPP should include only digits';ru='КПП должен включать только цифры'"),,ColorHighlightIncorrectValues);
						
						TextForIncorrectKPP = NStr("en='%
		|KPP includes not only digits';ru='%1
		|КПП содержит не только цифры'");
						
						ReturnStructure.ExtendedKPPPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectKPP, KPP);
						
						ReturnStructure.NoErrorsByKPP = False;
						
					EndIf;
					
					If ReturnStructure.NoErrorsByKPP Then
						
						ControlPart = Mid(KPP, 5, 2);
						
						SeparateDivisionFlag = ControlPart = "02"
						//Registration with the taxpayer - a Russian company at the location of its separate division depending on the division type 
						or ControlPart = "03" //Registration with the taxpayer - a Russian company at the location of its branch that does not act as taxes and receipts payment organization 
						or ControlPart = "04" //Registration with the taxpayer - a Russian company at the location of its separate division depending on the division type 
						or ControlPart = "05" //Registration with the taxpayer - a Russian company at the location of its separate division depending on the division type
						or ControlPart = "30" //Russian company - the tax agent not considered as a taxpayer
						or ControlPart = "31" //Registration with the taxpayer - a Russian company at the location of a separate subdivision in respect of which no registration procedure is not executed under paragraph 3 of Article 55 of the Russian Federation Civil Code that acts as taxes and receipts payment organization 
						or ControlPart = "32" //Registration with the taxpayer - a Russian company at the location of a separate subdivision in respect of which no registration procedure is executed under paragraph 3 of Article 55 of the Russian Federation Civil Code that does not act as taxes and receipts payment organization 
						or ControlPart = "43" //Registration with the Russian company at the location of its branch (similar to the old codes "02", "03" - Ministry of Finance Notification dated 6/2/2008 No. BH-6-6/396@ "Concerning the application of "SPPUNO" directory code) 
						or ControlPart = "44" //Registration with the Russian company at the location of its representative office (similar to the old codes "04", "05" - Ministry of Finance Notification dated 6/2/2008 No. BH-6-6/396@ "Concerning the application of "SPPUNO" directory code) 
						or ControlPart = "45";//Registration with the Russian company at the location of its separate division (similar to the old codes "31", "32" - Ministry of Finance Notification dated 6/2/2008 No. BH-6-6/396@ "Concerning the application of "SPPUNO" directory code)
						
						MainDivisionFlag = ControlPart = "01" 
						or ControlPart = "50" //At the place of registration as the largest taxpayer
						or ControlPart = "51" //Registration with foreign companies’ branches 
						or ControlPart = "52" //Registration with foreign companies divisions in the Russian Federation established by the foreign organization branch in a foreign country 
						or ControlPart = "60" //Registration with foreign embassies
						or ControlPart = "61" //Registration with the foreign countries consulates
						or ControlPart = "62" //Registration with the representative office similar to diplomatic
						or ControlPart = "63" //Registration with the international companies
						or ControlPart = "70" //Registration with foreign and international companies that own real estate in the Russian Federation, except for vehicles belonging to the real estate
						or ControlPart = "71" //Registration with foreign and international companies with vehicles in the Russian Federation not related to the real estate
						or ControlPart = "72" //Registration with foreign and international companies with marine transport in the Russian Federation
						or ControlPart = "73" //Registration with foreign and international companies with river transport in the Russian Federation
						or ControlPart = "74" //Registration with foreign and international companies with aerial vehicles in the Russian Federation
						or ControlPart = "75" //Registration with foreign and international companies with space crafts in the Russian Federation
						or ControlPart = "80" //Registration of foreign and international companies as rouble accounts of the "C" (current) types are opened in banks
						or ControlPart = "81" //Registration of foreign and international companies as accounts of the "I" (investment) types are opened in banks
						or ControlPart = "82" //registration of foreign and international companies as accounts of the "S" (special) types are opened in banks
						or ControlPart = "83" //Registration of foreign and international companies as accounts of the "C" (current) types in the foreign currency are opened in the banks
						or ControlPart = "84";//Registration of foreign and international companies as correspondent accounts are opened in the banks 
						
						If Not MainDivisionFlag and Not SeparateDivisionFlag Then
							
							ReturnStructure.KPPEnteredCorrectly = False;
							
							ReturnStructure.LabelExplanationsOfIncorrectKPP = New FormattedString(NStr("en='KPP does not correspond to format';ru='КПП не соответствует формату'"),,ColorHighlightIncorrectValues);
							
							TextForIncorrectKPP = NStr("en='%
		|KPP does not correspond to the format';ru='%1
		|КПП не соответствует формату'");
							
							ReturnStructure.ExtendedKPPPresentation = StringFunctionsClientServer.PlaceParametersIntoString(TextForIncorrectKPP, KPP);
							
							ReturnStructure.NoErrorsByKPP = False;
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return ReturnStructure;
	
EndFunction	

// Fills in the values list Receiver from the values list Source
//
Procedure FillListByList(Source,Receiver) Export

	Receiver.Clear();
	For Each ListIt IN Source Do
		Receiver.Add(ListIt.Value, ListIt.Presentation);
	EndDo;

EndProcedure

// Function receives items present in each array
//
// Parameters:
//  Array1	 - array	 - first
//  array Array2	 - array	 - second
// array Return value:
//  array - array of values that are contained in two arrays
Function GetMatchingArraysItems(Array1, Array2) Export
	
	Result = New Array;
	
	For Each Value IN Array1 Do
		If Array2.Find(Value) <> Undefined Then
			Result.Add(Value);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure SetPictureForComment(GroupAdditional, Comment) Export
	
	If ValueIsFilled(Comment) Then
		GroupAdditional.Picture = PictureLib.WriteSMS;
	Else
		GroupAdditional.Picture = New Picture;
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////// 
// INTERACTION PROCEDURES AND FUNCTIONS

// Generates a structure of contact info fields of type Telephone or MobilePhone by a telephone presentation
//
// Parameters
//  Presentation  - String - String info with a telephone number
//
// Returns:
//   Structure   - generated structure
//
Function ConvertNumberForSMSSending(val Number) Export
	
	Result = New Structure("NumberIsCorrect, SendingNumber");
	
	// Clear user separators
	CharsToReplace = "()- ";
	For CharacterNumber = 1 To StrLen(CharsToReplace) Do
		Number = StrReplace(Number, Mid(CharsToReplace, CharacterNumber, 1), "");
	EndDo;
	
	// Russian phone code 7 (domestic call begins with 8), codes of mobile operators begin with 9.
	If Left(Number, 2) = "89" Then
		Number = Mid(Number, 2);
	ElsIf Left(Number, 3) = "+79" Then
		Number = Mid(Number, 3);
	Else
		Result.NumberIsCorrect = False;
		Return Result;
	EndIf;
	
	// Russian telephone numbers are ten-digits
	If StrLen(Number) = 10
		AND StringFunctionsClientServer.OnlyNumbersInString(Number) Then
		
		Result.SendingNumber = "+7" + Number;
		Result.NumberIsCorrect = True;
	Else
		Result.NumberIsCorrect = False;
	EndIf;
	
	Return Result;
	
EndFunction

// PROCEDURES AND FUNCTIONS OF WORK WITH DYNAMIC LISTS

// Procedure sets filter in dynamic list for equality.
//
Procedure SetDynamicListFilterToEquality(Filter, LeftValue, RightValue) Export
	
	FilterItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue	 = LeftValue;
	FilterItem.ComparisonType	 = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = RightValue;
	FilterItem.Use  = True;
	
EndProcedure // SetFilterForDynamicList()

// Deletes dynamic list filter item
//
//Parameters:
//List  - processed dynamic
//list, FieldName - layout field name filter by which should be deleted
//
Procedure DeleteListFilterItem(List, FieldName) Export
	
	SetElements = List.SettingsComposer.Settings.Filter;
	CommonUseClientServer.DeleteItemsOfFilterGroup(SetElements,FieldName);
	
EndProcedure // DeleteListFilterItem()

// Sets dynamic list filter item
//
//Parameters:
//List			- processed dynamic
//list, FieldName			- layout field name filter on which
//should be set, ComparisonKind		- filter comparison kind, by default - Equal,
//RightValue 	- filter value
//
Procedure SetListFilterItem(List, FieldName, RightValue, Use = True, ComparisonType = Undefined) Export
	
	SetElements = List.SettingsComposer.Settings.Filter;
	CommonUseClientServer.SetFilterItem(SetElements,FieldName,RightValue,ComparisonType,,Use);
	
EndProcedure // SetListFilterItem()

// Changes dynamic list filter item
//
//Parameters:
//List         - processed dynamic
//list, FieldName        - layout field name filter on which
//should be set, ComparisonKind   - filter comparison kind, by default - Equal,
//RightValue - filter
//value, Set     - shows that it is required to set filter
//
Procedure ChangeListFilterElement(List, FieldName, RightValue = Undefined, Set = False, ComparisonType = Undefined, FilterByPeriod = False, QuickAccess = False) Export
	
	SetElements = List.SettingsComposer.Settings.Filter;
	CommonUseClientServer.ChangeFilterItems(SetElements,FieldName,,RightValue,ComparisonType,Set);
	
EndProcedure // ChangeListFilterItem()

// ACCRUAL UNIQUE IDENTIFIER

// Until March 31, 2014 an accrual unique identifier can be set to the "Payment destination" attribute.
// accrual unique identifier is specified first in the "Payment presence" attribute and consists of 23 characters: first three characters take value "UID", characters from 4 to 23 match the value of the accrual unique identifier.
// For the specified information about accrual unique identifier, character "///" is used after accrual unique identifier.
// For example: "UIN12345678901234567890///".
// (In general, UIN can contain not only digits).

// Returns a statuses list of sender p/p for the transfer to the budget
//
// Returns:
//  ValuesList - in which items are created with the possible sender status values
//
Function PayerStatuses(Period = Undefined) Export
	
	Statuses = New Map; // Key - code, Value - presentation; use match to describe changes in the classifier versions easier
	
	// Old rules
	
	Statuses.Insert("01", "01 - tax payer (fees payer) - legal entity");
	Statuses.Insert("02", "02 - tax agent");
	Statuses.Insert("03", "03 - institution of the state postal service that have issued the settlement document for the transfer of payments paid by the individuals to the budget system");
	Statuses.Insert("04", "04 - tax body");
	Statuses.Insert("05", "05 - regional authorities of the catchpoles Federal service");
	Statuses.Insert("06", "06 - foreign economic activity participant - legal entity");
	Statuses.Insert("07", "07 - customs body");
	Statuses.Insert("08", "08 - other charges payer who transfers the payments to the Russian Federation budget system (except the payments managed by the tax authorities)");
	Statuses.Insert("09", "09 - tax payer (fees payer) - individual entrepreneur");
	Statuses.Insert("10", "10 - tax (fees) payer - privately practising notary");
	Statuses.Insert("11", "11 - tax (fees) payer - lawyer established the advocatory office");
	Statuses.Insert("12", "12 - tax (fees) payer - head of the farming enterprise");
	Statuses.Insert("13", "13 - tax payer (fees payer) - other individual - client of a bank (account holder)");
	Statuses.Insert("14", "14 - tax payer that pays to individuals (p.p. 1 p.1 art. 235 Russian Federation Tax Code)");
	Statuses.Insert("15", "15 - credit company that prepared accounting document for the total amount to transfer to the Russian Federation budget system of the payments paid by individuals without opening a bank account");
	Statuses.Insert("16", "16 - foreign economic activity participant - individual");
	Statuses.Insert("17", "17 - participant of the foreign economic activity - individual entrepreneur");
	Statuses.Insert("18", "18 - customs charges payer who is not an applicant and who is obligatory to pay the customs charges according to the Russian Federation legislation");
	Statuses.Insert("19", "19 - companies which have issued the settlement document for the transfer to an account of the treasury authority of funds deducted from the earnings (income) for the customs debt repayment of the individual debitor");
	Statuses.Insert("20", "20 - credit institution which have issued the settlement document for the each individual's payment to transfer the customs fees paid by the individuals without opening a banking account.");
	
	If PaymentToBudgetAttributesNewRulesApplied(Period) Then 
		
		Statuses.Insert("03", "03 - company of the federal postal service that made an order for each payment of the individual");
		Statuses.Insert("08", "08 - legal entity (sole proprietorship) that pays insurance contributions and other payments");
		Statuses.Insert("14", "14 - taxpayer that pays to individuals");
		Statuses.Insert("15", "15 - credit company (credit company branch), payment agent, Federal postal service company that prepared a payment order for the total amount with the registry");
		Statuses.Insert("19", "19 - companies that transfer money withheld from salary on grounds of executive document");
		Statuses.Insert("20", "20 - credit company (credit company branch), payment agent that prepared an order on each payment of the individual");
		Statuses.Insert("21", "21 - responsible member of taxpayers consolidated group");
		Statuses.Insert("22", "22 - member of taxpayers consolidated group");
		Statuses.Insert("23", "23 - authorities that control insurance payments");
		Statuses.Insert("24", "24 - individual that pays the insurance payments and other payments");
		Statuses.Insert("25", "25 - banks - the guarantors that prepared an order on money transfer to the Russian Federation budget system for VAT amount payer excessively received by them (credited to them) as a result of VAT refund in a declarative manner, as well as the excise tax payment. It is calculated by excise goods implementation outwards the Russian Federation, as well as excise taxes in the amount of the excise advance payment by alcohol and (or) excisable alcohol-containing products");
		Statuses.Insert("26", "26 - founders (participants) of the debtor, the owners of debtor's property - a unitary enterprise or third parties that prepared an order to pay the debt on mandatory payments included in the creditors demands register during the procedures applied in the bankruptcy case");
		
	EndIf;
	
	List = New ValueList;
	For Each KeyAndValue IN Statuses Do
		List.Add(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	List.SortByValue();
	
	Return PackMatchToValuesList(Statuses);
	
EndFunction

Function PackMatchToValuesList(Map)
	
	List = New ValueList;
	For Each KeyAndValue IN Map Do
		List.Add(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	List.SortByValue();
	Return List;
	
EndFunction

Function StartApplyPaymetID() Export
	
	// The Central Bank of the RF Order No 3025-U dated July 15, 2013.
	
	Return '20140331';
	
EndFunction

Function RecognizeInUINPaymentDestination(Val PaymentDestination)
	
	// Until 2014 UIN could be specified at the end of payment destination - "///UIN0"
	
	Definition = New Structure;
	Definition.Insert("Definition", ""); // String containing UIN description (23, 26 characters or more)
	Definition.Insert("Value", ""); // UIN itself (row contains no more than 20 characters)
	
	Signature                 = "WIN";
	Delimiter               = "///";
	ValueMaxLength = LengthUIN();
	
	SignatureLength   = StrLen(Signature);
	SeparatorLength = StrLen(Delimiter);
	
	StringToParse = TrimL(PaymentDestination);
	DescriptionLength = StrLen(PaymentDestination) - StrLen(StringToParse);
	
	If Left(StringToParse, SignatureLength) <> Signature Then
		// UIN is not found
		Return Definition;
	EndIf;
	
	StringToParse = Mid(StringToParse, SignatureLength + 1); // Remove signature
	DescriptionLength = DescriptionLength + SignatureLength;
	
	SeparatorPosition = Find(StringToParse, Delimiter); // ideally - 21
	If SeparatorPosition = 0 Then
		ValueLength     = StrLen(StringToParse);
		DescriptionLength     = DescriptionLength + ValueLength;
	Else
		ValueLength     = SeparatorPosition - 1;
		DescriptionLength     = DescriptionLength + ValueLength + SeparatorLength;
		StringToParse = Left(StringToParse, ValueLength);
	EndIf;
	
	// Make sure that value contains UIN - 1 character 0 or 20 characters
	StringToParse = StrReplace(StringToParse, " ", "");
	If StrLen(StringToParse) > ValueMaxLength Then
		// UIN is not found - too many characters 
		Return Definition;
	EndIf;
	
	// UIN is found
	Definition.Insert("Definition", Left(PaymentDestination, DescriptionLength));
	Definition.Insert("Value", StringToParse);
	Return Definition;
	
EndFunction

Function LengthUIN()
	
	Return 20;
	
EndFunction

Function SignatureUIN()
	
	Return "WIN";
	
EndFunction

Function SeparatorUIN()
	
	Return "///";
	
EndFunction

Function DescriptionUIN(Val PaymentIdentifier)
	
	If IsBlankString(PaymentIdentifier) Then
		Return "";
	EndIf;
	
	NormativeLength = LengthUIN();
	ActualLength = StrLen(PaymentIdentifier);
	
	If ActualLength > NormativeLength Then
		PaymentIdentifier = Left(PaymentIdentifier, NormativeLength);
	Else
		PaymentIdentifier = StringFunctionsClientServer.SupplementString(
			PaymentIdentifier,
			NormativeLength,
			" ",
			"RIGHT");
	EndIf;
	
	Return SignatureUIN() + PaymentIdentifier + SeparatorUIN();
	
EndFunction

Function BeginsNewPaymentDetailsIntoBudgetRules() Export
	
	// Ministry of Finance order No. 107 from 11/12/2013
	Return '20140204'; // Also this date (year number) is specified in messages in this module.
	
EndFunction

Function PaymentToBudgetAttributesNewRulesApplied(Period) Export
	
	BeginsNewPaymentDetailsIntoBudgetRules = BeginsNewPaymentDetailsIntoBudgetRules();
	
	Return Period = Undefined
		OR Not ValueIsFilled(Period)
		OR Period >= BeginsNewPaymentDetailsIntoBudgetRules();
	
EndFunction

Procedure ReplaceInUINPaymentDestination(PaymentDestination, Val PaymentIdentifier, Val Date = Undefined, Val PaymentToBudget = True) Export
	
	// Replace (add) UIN (accrual
	// unique identifier) From January 1, 2014 to March 30, 2014 it is specified as payment
	If Date <> Undefined 
		AND Date < BeginsNewPaymentDetailsIntoBudgetRules() Then
		// UIN is not used
		Return;
	EndIf;
	
	UINPaymentDestination = RecognizeInUINPaymentDestination(PaymentDestination);
	
	If Not PaymentToBudget 
	   OR (Date <> Undefined
		  AND Date >= StartApplyPaymetID()) Then
		PaymentIdentifier = "";
	EndIf;
	
	If Date <> Undefined 
		AND Date >= StartApplyPaymetID() Then
		// UIN should not be specified as payment destination, you should delete
		PaymentIdentifier = "";
	ElsIf TrimAll(UINPaymentDestination.Value) = TrimAll(PaymentIdentifier) Then
		// Everything is good
		Return;
	EndIf;
	
	DescriptionUIN = DescriptionUIN(PaymentIdentifier);
	
	If ValueIsFilled(UINPaymentDestination.Definition) Then
		// Delete old description
		PaymentDestination = StrReplace(PaymentDestination, UINPaymentDestination.Definition, "");
	EndIf;
	
	PaymentDestination = DescriptionUIN + PaymentDestination;
	
EndProcedure

Function PaymentBases(EnumKind, Period = Undefined) Export
	
	PaymentBases = New ValueList;
		
	If EnumKind = PredefinedValue("Enum.BudgetTransferKinds.TaxPayment") Then
		PaymentBases = TaxPaymentBases(Period);
	ElsIf EnumKind = PredefinedValue("Enum.BudgetTransferKinds.CustomsPayment") Then
		PaymentBases = CustomPaymentBases(Period);
	Else
		PaymentBases.Add(UnfilledValue(), NStr("en='0 - value is not filled in';ru='0 - значение не заполняется'"));
	EndIf;
	
	Return PaymentBases;
	
EndFunction

Function TaxPaymentBases(Period = Undefined)
	
	Bases = New ValueList;
	
	Bases.Add("CP", "CP - current year payments");
	Bases.Add("ZD", "ZD - voluntary debt payment by the elapsed time");
	Bases.Add("TP", "TP - debt payment on demand of the tax authority on taxes payment (fees)");
	Bases.Add("AP", "AP - debt repayment by inspection act");
	Bases.Add("AR", "AR - repayment of debts by the executive document");
	Bases.Add("BF", "BF - individual current payment individual - bank customer (account holder), payed from their bank account");
	Bases.Add("information register", "PC - repayment of the installment debt");
	Bases.Add("OT", "OT - repayment of delayed debt");
	Bases.Add("PT", "PT - repayment of the restructured debt");
	Bases.Add("PR", "PR - repayment of debt paused to be charged");
	
	If PaymentToBudgetAttributesNewRulesApplied(Period) Then
		Bases.Add("IN", "IN - payment of the investment tax loan");
		Bases.Add("PB", "PB - payment of the debt by the debtor during the procedures applied in the bankruptcy case");
		Bases.Add("TP", "TP - founder (participant) payment of the debtor, the owner of debtor property - a unitary enterprise or a third party debt in the course of the procedures applied in the bankruptcy case");
		Bases.Add("ZT", "ZT - payment of the current debt during procedures applied in the bankruptcy case");
	Else
		Bases.Add("VU", "VU - repayment of deferred debt due to the introduction of external management");
	EndIf;
	
	Bases.Add(UnfilledValue(), "0 - can not specify a particular value");
	
	Return Bases;
	
EndFunction

Function CustomPaymentBases(Period = Undefined)
	
	Bases = New ValueList;
	
	If PaymentToBudgetAttributesNewRulesApplied(Period) Then
		Bases.Add("DE", "DE - goods declaration");
	Else
		Bases.Add("DE", "DE - customs declaration");
	EndIf;
	Bases.Add("PO", "PO - customs pay-in slip");
	If Not PaymentToBudgetAttributesNewRulesApplied(Period) Then
		Bases.Add("KV", "KV - receipt recree (when paying the fine)");
	EndIf;
	If PaymentToBudgetAttributesNewRulesApplied(Period) Then
		Bases.Add("CC", "CC - adjustment of the customs value, customs payment or the goods declaration");
	Else
		Bases.Add("CC", "CC - form of adjustments to the customs value and customs duties");
	EndIf;
	Bases.Add("ID", "ED - executive document");
	Bases.Add("CO", "CO - the collection order");
	Bases.Add("TY", "TY - requirement on customs charges payment");
	Bases.Add("BD", "BD - documents of financial and economic activity");
	Bases.Add("EN", "EN - encashment document");
	Bases.Add("KP", "KP - agreement of interaction in case of payment by the large payers of the summarized fees in the centralized order");
	Bases.Add("00", "00 - other cases");

	Bases.Add(UnfilledValue(), "0 - can not specify a particular value");
	
	Return Bases;
	
EndFunction 

Function UnfilledValue() Export
	
	// If you can not specify a particular value, specify 0.
	// All attributes must be filled in.
	
	Return "0";
EndFunction

Function PaymentTypes(EnumKind, Period = Undefined) Export
	
	PaymentTypes = New ValueList;
	
	If EnumKind = PredefinedValue("Enum.BudgetTransferKinds.TaxPayment") Then
		PaymentTypes = TaxPaymentTypes(Period);
	ElsIf EnumKind = PredefinedValue("Enum.BudgetTransferKinds.CustomsPayment") Then
		PaymentTypes = CustomPaymentTypes(Period);
	Else
		PaymentTypes.Add(UnfilledValue(), NStr("en='0 - value is not filled in';ru='0 - значение не заполняется'"));
	EndIf;
	
	Return PaymentTypes;
	
EndFunction

Function TaxPaymentTypes(Period = Undefined)
	
	PaymentTypes = New ValueList;
	
	If PaymentToBudgetAttributesNewRulesApplied(Period) Then
		PaymentTypes.Add(UnfilledValue(), "0 - all except for penalties and percents");
		PaymentTypes.Add(PenaltiesPaymentTypes(), "PE - penalty fee payment");
		PaymentTypes.Add("PC", "PC - payment of percent");
	Else
		PaymentTypes.Add("TF", "TF - tax or fee payment");
		PaymentTypes.Add("PL", "PL - payment");
		PaymentTypes.Add("GP", "GP - duty payment");
		PaymentTypes.Add("VZ", "VZ - contribution payment");
		PaymentTypes.Add(AdvancePaymentType(), "AB - payment of advance or prepayment (including the decade payments)");
		PaymentTypes.Add(PenaltiesPaymentTypes(), "PE - penalty fee payment");
		PaymentTypes.Add("PC", "PC - payment of percent");
		PaymentTypes.Add(TaxPenaltyPaymentType(), "CA - tax sanctions set by the RF Tax Code");
		PaymentTypes.Add(AdministrativeFinePaymentType(), "AF - administrative fines");
		PaymentTypes.Add(OtherFinePaymentType(), "OF - other fines set by the corresponding normative acts");
		PaymentTypes.Add(UnfilledValue(),  "0 - can not specify a particular value");
	EndIf;
	
	Return PaymentTypes;
	
EndFunction

Function CustomPaymentTypes(Period = Undefined)
	
	PaymentTypes = New ValueList;
	
	If PaymentToBudgetAttributesNewRulesApplied(Period) Then
		PaymentTypes.Add(UnfilledValue(), "0 - current payment");
		
		PaymentTypes.Add("PCS", "PCS - payment of fine");
		PaymentTypes.Add("ZD", "ZD - payment on account of the debt repayment");
		PaymentTypes.Add(PenaltiesPaymentTypes(), "PE - penalty fee payment");
	Else
		PaymentTypes.Add("TP", "TP - current payment");
		
		PaymentTypes.Add("PCS", "PCS - payment of fine");
		PaymentTypes.Add("ZD", "ZD - payment on account of the debt repayment");
		PaymentTypes.Add(PenaltiesPaymentTypes(), "PE - penalty fee payment");
		
		PaymentTypes.Add(UnfilledValue(), "0 - can not specify a particular value");
	EndIf;
	
	Return PaymentTypes;
	
EndFunction

Function AdvancePaymentType() Export
	
	Return "AB";
	
EndFunction

Function PenaltiesPaymentTypes() Export
	
	Return "PE";
	
EndFunction

Function IsPaymentTypeFine(PaymentType) Export
	
	Return PaymentType = TaxPenaltyPaymentType() 
		Or PaymentType = AdministrativeFinePaymentType()
		Or PaymentType = OtherFinePaymentType();
	
EndFunction

Function TaxPenaltyPaymentType()
	
	Return "AS";
	
EndFunction

Function AdministrativeFinePaymentType()
	
	Return "ASH";
	
EndFunction

Function OtherFinePaymentType()
	
	Return "ISH";
	
EndFunction

Function EmptyBCCAllowed(EnumKind, RecipientAccountNumber, Period) Export
	
	Return EnumKind = PredefinedValue("Enum.BudgetTransferKinds.OtherPayment")
		AND IsStateServicesExecutiveAccount(RecipientAccountNumber, Period);
	
EndFunction

Function IsStateServicesExecutiveAccount(Val AccountNo, Period)
	
	If Not SmallBusinessClientServer.PaymentToBudgetAttributesNewRulesApplied(Period) Then
		Return False;
	EndIf;
	
	If StrLen(TrimR(AccountNo)) <> 20 Then
		Return False;
	EndIf;
	
	BalanceAccount       = Left(AccountNo, 5);
	PersonalAccountFlag = Mid(AccountNo, 14, 1);
	
	// p.2 Application 4 to 107n
	Return (BalanceAccount = "40302")
		Or (BalanceAccount = "40501" AND PersonalAccountFlag = "2")
		Or (BalanceAccount = "40601" AND (PersonalAccountFlag = "1" Or PersonalAccountFlag = "3"))
		Or (BalanceAccount = "40701" AND (PersonalAccountFlag = "1" Or PersonalAccountFlag = "3"))
		Or (BalanceAccount = "40503" AND PersonalAccountFlag = "4")
		Or (BalanceAccount = "40603" AND PersonalAccountFlag = "4")
		Or (BalanceAccount = "40703" AND PersonalAccountFlag = "4");
	
EndFunction

