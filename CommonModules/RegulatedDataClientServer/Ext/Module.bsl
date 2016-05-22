////////////////////////////////////////////////////////////////////////////////
// The "Working with Counterparties" subsystem
// Procedures and functions of checking that regulated data is filled correctly
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Checks compliance with TIN requirements.
//
// Parameters:
//  TIN                - String - The individual taxpayer number being validated.
//  ThisLegalEntity - Boolean - shows whether the TIN owner is a legal entity.
//  MessageText     - String - Text of the message of errors found.
//
// Returns:
//  True       - TIN meets the requirements;
//  False         - TIN does not meet the requirements.
//
Function TINMeetsTheRequirements(Val TIN, ThisLegalEntity, MessageText) Export

	MeetsRequirements = True;
	MessageText = "";

	TIN      = TrimAll(TIN);
	TINLength = StrLen(TIN);

	If ThisLegalEntity = Undefined Then
		MessageText = MessageText + NStr("en = 'Not defined TIN owner type.'");
		Return False;
	EndIf;
	
	If Not StringFunctionsClientServer.OnlyNumbersInString(TIN) Then
		MeetsRequirements = False;
		MessageText = MessageText + NStr("en = 'TIN should contain only numbers.'");
	EndIf;

	If  ThisLegalEntity AND TINLength <> 10 Then
		MeetsRequirements = False;
		MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
			+ NStr("en = 'TIN of legal entity should contain 10 numbers.'");
	ElsIf Not ThisLegalEntity AND TINLength <> 12 Then
		MeetsRequirements = False;
		MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
			+ NStr("en = 'Individual TIN should contain 12 number.'");
	EndIf;

	If MeetsRequirements Then

		If ThisLegalEntity Then

			CheckSum = 0;

			For IndexOf = 1 To 9 Do

				If IndexOf = 1 Then
					Factor = 2;
				ElsIf IndexOf = 2 Then
					Factor = 4;
				ElsIf IndexOf = 3 Then
					Factor = 10;
				ElsIf IndexOf = 4 Then
					Factor = 3;
				ElsIf IndexOf = 5 Then
					Factor = 5;
				ElsIf IndexOf = 6 Then
					Factor = 9;
				ElsIf IndexOf = 7 Then
					Factor = 4;
				ElsIf IndexOf = 8 Then
					Factor = 6;
				ElsIf IndexOf = 9 Then
					Factor = 8;
				EndIf;

				Digit = Number(Mid(TIN, IndexOf, 1));
				CheckSum = CheckSum + Digit * Factor;

			EndDo;
			
			CheckDigit = (CheckSum %11) %10;

			If CheckDigit <> Number(Mid(TIN, 10, 1)) Then
				MeetsRequirements = False;
				MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
				               + NStr("en = 'Check number for TIN not matches with calculated.'");
			EndIf;

		Else

			CheckSum11 = 0;
			CheckSum12 = 0;

			For IndexOf = 1 To 11 Do

				// Calculation of multipliers for the 11th and 12th digits.
				If IndexOf = 1 Then
					Factor11 = 7;
					Factor12 = 3;
				ElsIf IndexOf = 2 Then
					Factor11 = 2;
					Factor12 = 7;
				ElsIf IndexOf = 3 Then
					Factor11 = 4;
					Factor12 = 2;
				ElsIf IndexOf = 4 Then
					Factor11 = 10;
					Factor12 = 4;
				ElsIf IndexOf = 5 Then
					Factor11 = 3;
					Factor12 = 10;
				ElsIf IndexOf = 6 Then
					Factor11 = 5;
					Factor12 = 3;
				ElsIf IndexOf = 7 Then
					Factor11 = 9;
					Factor12 = 5;
				ElsIf IndexOf = 8 Then
					Factor11 = 4;
					Factor12 = 9;
				ElsIf IndexOf = 9 Then
					Factor11 = 6;
					Factor12 = 4;
				ElsIf IndexOf = 10 Then
					Factor11 = 8;
					Factor12 = 6;
				ElsIf IndexOf = 11 Then
					Factor11 = 0;
					Factor12 = 8;
				EndIf;

				Digit = Number(Mid(TIN, IndexOf, 1));
				CheckSum11 = CheckSum11 + Digit * Factor11;
				CheckSum12 = CheckSum12 + Digit * Factor12;

			EndDo;

			CheckDigit11 = (CheckSum11 %11) %10;
			CheckDigit12 = (CheckSum12 %11) %10;

			If CheckDigit11 <> Number(Mid(TIN,11,1)) OR CheckDigit12 <> Number(Mid(TIN,12,1)) Then
				MeetsRequirements = False;
				MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
				               + NStr("en = 'Check number for TIN not matches with calculated.'");
			EndIf;

		EndIf;

	EndIf;

	Return MeetsRequirements;

EndFunction 

// Checks correspondence of the Tax Registration Reason Code (KPP) to the requirements.
//
// Parameters:
//  KPP          - String - The Tax Registration Reason Code (KPP) being verified.
//  MessageText - String - Text of the message of errors found.
//
// Returns:
//  True       - KPP meets the requirements;
//  False         - KPP does not meet the requirements.
//
Function KPPMeetsTheRequirements(Val KPP, MessageText) Export

	MeetsRequirements = True;
	MessageText           = "";

	KPP      = TrimAll(KPP);
	KPPLength = StrLen(KPP);

	If Not StringFunctionsClientServer.OnlyNumbersInString(KPP) Then
		MeetsRequirements = False;
		MessageText = MessageText + NStr("en = 'KPP should contain numbers only.'");
	EndIf;

	If KPPLength <> 9 Then
		MeetsRequirements = False;
		MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "") +
			NStr("en = 'KPP should contain 9 numbers.'");
	EndIf;

	Return MeetsRequirements;

EndFunction 

// Checks correspondence of OGRN to the requirements.
//
// Parameters:
//  OGRN               - String - The Principal State Registration Number (OGRN) being verified.
//  ThisLegalEntity - Boolean - shows whether the OGRN owner ia a legal entity.
//  MessageText     - String - Text of the message of errors found.
//
// Returns:
//  True       - OGRN meets the requirements;
//  False         - OGRN does not meet the requirements.
//
Function MSRNMeetsTheRequirements(Val OGRN, ThisLegalEntity, MessageText) Export

	MeetsRequirements = True;
	MessageText = "";

	OGRN = TrimAll(OGRN);
	OGRNLength = StrLen(OGRN);
	
	If ThisLegalEntity = Undefined Then
		MessageText = MessageText + NStr("en = 'Not defined MNSR owner type.'");
		Return False;
	EndIf;

	If Not StringFunctionsClientServer.OnlyNumbersInString(OGRN) Then
		MeetsRequirements = False;
		MessageText = MessageText + NStr("en = 'MSRN should contain only numbers.'")
	EndIf;

	If ThisLegalEntity AND OGRNLength <> 13 Then
		MeetsRequirements = False;
		MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
		               + NStr("en = 'Legal entity MSRN should contain only 13 numbers.'");
	ElsIf Not ThisLegalEntity AND OGRNLength <> 15 Then
		MeetsRequirements = False;
		MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
		               + NStr("en = 'Individual MSRN should contain only 15 numbers.'");
	EndIf;

	If MeetsRequirements Then

		If ThisLegalEntity Then

			CheckDigit = Right(Format(Number(Left(OGRN, 12)) % 11, "NZ=0; NG=0"), 1);

			If CheckDigit <> Right(OGRN, 1) Then
				MeetsRequirements = False;
				MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
				               + NStr("en = 'Check number for MSRN not matches with calculated.'");
			EndIf;

		Else

			CheckDigit = Right(Format(Number(Left(OGRN, 14)) % 13, "NZ=0; NG=0"), 1);

			If CheckDigit <> Right(OGRN, 1) Then
				MeetsRequirements = False;
				MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
				               + NStr("en = 'Check number for MSRN not matches with calculated.'");
			EndIf;

		EndIf;

	EndIf;

	Return MeetsRequirements;

EndFunction 

// Checks correspondence of OKPO to requirements of standards.
//
// Parameters:
//  VerifiableCode         - String - The OKPO code being verified;
//  ThisLegalEntity     - Boolean - shows whether the OKPO code owner is a legal entity;
//  MessageText         - String - text of the message of errors found in the verified OKPO code;
//
// Returns:
//  Boolean.
//
Function CodeByOKPOMeetsTheRequirements(Val VerifiableCode, ThisLegalEntity, MessageText = "") Export
	
	VerifiableCode = TrimAll(VerifiableCode);
	MessageText = "";
	CodeLength = StrLen(VerifiableCode);

	If ThisLegalEntity = Undefined Then
		MessageText = MessageText + NStr("en = 'The OKPO owner type is not defined.'");
		Return False;
	EndIf;
	
	If Not StringFunctionsClientServer.OnlyNumbersInString(VerifiableCode) Then
		MessageText = MessageText + NStr("en = 'The OKPO code shall consist of digits only.'") + Chars.LF;
	EndIf;

	If ThisLegalEntity AND CodeLength <> 8 Then
		MessageText = MessageText + NStr("en = 'The OKPO code of a legal person shall consist of 8 digits.'") + Chars.LF;
	ElsIf Not ThisLegalEntity AND CodeLength <> 10 Then
		MessageText = MessageText + NStr("en = 'The OKPO code of a physical person shall consist of 10 digits.'") + Chars.LF;
	EndIf;
	
	If Not IsBlankString(MessageText) Then
		MessageText = TrimAll(MessageText);
		Return False;
	EndIf;
	
	If Not ClassifierCodeCorrect(VerifiableCode) Then
		MessageText = NStr("en = 'Check number for OKPO code does not match the calculated one.'");
		Return False
	EndIf;
	
	Return True;
	
EndFunction 

// Checks the number of the insurance certificate for correspondence to requirements of RPF.
//
// Parameters:
// 	InsuranceNumber - RPF insurance number. The string should be entered in accordance with the following pattern: "999-999-999 99".
// 	MessageText - text of the message of the input insurance number entering error.
//
Function PFRInsuaranceNumberMeetsTheRequirements(Val InsuranceNumber, MessageText) Export
	
	MessageText = "";
	
	RowOfDigits = StrReplace(InsuranceNumber, "-", "");
	RowOfDigits = StrReplace(RowOfDigits, " ", "");
	
	If IsBlankString(RowOfDigits) Then
		MessageText = MessageText + NStr("en = 'Insurance number is not filled in'");
		Return False;
	EndIf;
	
	If StrLen(RowOfDigits) < 11 Then
		MessageText = MessageText + NStr("en = 'Insurance number is specified incompletely'");
		Return False;
	EndIf;
	
	If Not StringFunctionsClientServer.OnlyNumbersInString(RowOfDigits) Then
		MessageText = MessageText + NStr("en = 'Insurance number should contain only numbers.'");
		Return False;
	EndIf;
	
	ChecksumNumber = Number(Right(RowOfDigits, 2));
	
	If Number(Left(RowOfDigits, 9)) > 1001998 Then
		Total = 0;
		For Ct = 1 To 9 Do
			Total = Total + Number(Mid(RowOfDigits, 10 - Ct, 1)) * Ct;
		EndDo;
		Balance = Total % 101;
		Balance = ?(Balance = 100, 0, Balance);
		If Balance <> ChecksumNumber Then
			MessageText = MessageText + NStr("en = 'Check number for insurance number does not match the calculated one.'");
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// Check of the control key in the personal account number
// (the 9th digit of the account number), the algorithm is set by the following document:
// "PROCEDURE FOR CALCULATING THE CONTROL KEY IN
// THE PERSONAL ACCOUNT NUMBER" (approved by CB RF 08.09.1997 N 515).
//
// Parameters:
//  AccountNo - String - bank  account number.
//  BIN - String, BIC of the bank where the account is opened.
//  IsBank - Boolean, True - Bank, False - CPC.
//
// Returns:
//  Boolean
//  True - the control key is correct.
//  False - the control key is incorrect.
//
Function AccountKeyDigitMeetsRequirements(AccountNo, BIN, IsBank = True)Export
	
	AccountNumberString = TrimAll(AccountNo);
	
	// If there is an alphabetical character in the 6th digit of the personal account (in case of use of a clearing currency), this character is replaced with a corresponding digit:
	Digit6 = Mid(AccountNumberString, 6, 1); 
	
	If Not StringFunctionsClientServer.OnlyNumbersInString(Digit6) Then
		AlphabeticValuesFor6thDigit = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray("A,In,From,E,N,K,M,R,T,X");
		Digit = AlphabeticValuesFor6thDigit.Find(Digit6);	
		If Digit = Undefined Then
			Return False;
		EndIf;
		Digit6 = String(Digit);
	EndIf;
	
	// For calculation of the control key, a combination of two attributes is used - the conditional number of CPC (if the personal account is opened in CPC) or of a credit company (if the personal account is opened in a credit company) and the personal account number.
	If IsBank Then
		ConventionalCONumber = Right(BIN, 3);
	Else
		ConventionalCONumber = "0" + Mid(BIN, 5, 2 );
	EndIf;
	
	AccountNumberString = ConventionalCONumber + Left(AccountNumberString,5) + Digit6 + Mid(AccountNumberString, 7);
	
	If StrLen(AccountNumberString) <> 23 Then
		Return False;
	EndIf;
	
	If Not StringFunctionsClientServer.OnlyNumbersInString(AccountNumberString) Then
		Return False;
	EndIf;
	
	Weights = "71371371371371371371371";
	CheckSum = 0;
	For Digit = 1 To 23 Do
		Multiplication = Number(Mid(AccountNumberString, Digit, 1)) * Number(Mid(Weights, Digit, 1));
		LeastSignificantDigit = Number(Right(String(Multiplication), 1));
		CheckSum = CheckSum + LeastSignificantDigit;
	EndDo;
	
	// when a sum divisible by 10 is received (the least significant digit is equal to 0), the control key value is considered to be correct.
	
	Return Right(String(CheckSum), 1) = "0";
	
EndFunction

// Checks correctness of the code based on a control number (the last digit in the code).
//
// Par. 50.1.024-2005 "Basic provisions and order of posting works of development, maintaining
// and use of All-Russian classifiers", annex B.
//
// The control number is calculated in the following way:
// 1. A system of weighting coefficients equal to the positive integers
// from 1 to 10 is assigned to code digits in the All-Russian classifier starting from the highest-order digit. If the code has more than 10 digits, the set of weighting coefficients is repeated.
// 2. Each digit in the code is multiplied by the digit weighting coefficient and the resulting products are summed.
// 3. The control number for a code is the residue of division of the resulting sum by the module "11".
// 4. The control number shall have one digit equal to a number from 0 to 9.
// If a residue equal to 10 is obtained, to get a single-digit
// control number, it is necessary to repeat the calculation using the second sequence of weighting coefficients shifted to the left by two digits (3 4 5,…). If
// in case of a repeated calculation the division residue is again equal to 10
// , then the value of the control number is affixed to "0".
//
// Parameters:
//  VerifiableCode - String - code for verification.
//
// Returns:
//  Boolean.
//
Function ClassifierCodeCorrect(VerifiableCode)
	
	ProductsSum = 0;
	For Position = 1 To StrLen(VerifiableCode)-1 Do
		Digit = Number(Mid(VerifiableCode, Position, 1));
		Weight = (Position - 1) % 10 + 1;
		ProductsSum = ProductsSum + Digit * Weight;
	EndDo;

	CheckDigit = ProductsSum % 11;
	If CheckDigit = 10 Then
		ProductsSum = 0;
		For Position = 1 To StrLen(VerifiableCode)-1 Do
			Digit = Number(Mid(VerifiableCode, Position, 1));
			Weight = (Position + 1) % 10 + 1;
			ProductsSum = ProductsSum + Digit * Weight;
		EndDo;
		CheckDigit = ProductsSum % 11;
	EndIf;
	
	CheckDigit = CheckDigit % 10;
	
	Return String(CheckDigit) = Right(VerifiableCode, 1);

EndFunction
	
#EndRegion
