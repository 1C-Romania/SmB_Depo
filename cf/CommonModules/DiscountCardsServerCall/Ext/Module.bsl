
#Region ProgramInterface

// The procedure forms the description of the catalog item  by value of other attributes.
//
Function SetDiscountCardName(Owner, CardOwner, CardCodeBarcode, CardCodeMagnetic) Export

	If Owner.CardType = Enums.CardsTypes.Mixed Then
		MapCodePage = TrimAll(CardCodeBarcode) + " / " + TrimAll(CardCodeMagnetic);
	ElsIf Owner.CardType = Enums.CardsTypes.Magnetic Then
		MapCodePage = TrimAll(CardCodeMagnetic);
	Else
		MapCodePage = TrimAll(CardCodeBarcode);
	EndIf;
	
	CurName = "" + ?(CardOwner.IsEmpty() OR Not Owner.ThisIsMembershipCard, "", ""+CardOwner+". ") +
	                      ?(Owner.IsEmpty(), "", ""+Owner+". ")
						  + MapCodePage;
						  
	Return CurName;

EndFunction // GetDiscountCardName()

#Region SearchDiscountCards

// Function searches for the discount cards according to data
// that received from magnetic card reader.
//
// Data
//  Parameters - Data array received from the magnetic card reader.
//
// Return
//  value Structure. Structure contains 2 tables of values: Registered
//  discount cards and NotRegisteredDiscountCards.
//
Function FindDiscountCardsByDataFromMagneticCardReader(Data, CodeType) Export
	
	SetPrivilegedMode(True);
	
	RegisteredDiscountCards = New Array;
	NotRegisteredDiscountCards = New Array;
	
	If TypeOf(Data) = Type("Array") Then
		// Let us decrypt track data according to those templates that are used in the kinds of discount cards.
		DecryptedData = DecryptMagneticCardCode(Data[1][1]);
		Data[1][3] = DecryptedData;
		
		If DecryptedData <> Undefined Then
			For Each Structure IN DecryptedData Do
				
				DiscountCardTemplate = Structure.Pattern;
				CardCode             = Data[0];
				For Each FieldData IN Structure.TracksData Do
					If FieldData.Field = Enums.MagneticCardsTemplateFields.Code Then
						CardCode = FieldData.FieldValue;
						Break;
					EndIf;
				EndDo;
				
				Query = New Query(
				"SELECT DISTINCT
				|	DiscountCardKinds.Ref AS Ref,
				|	DiscountCardKinds.ThisIsMembershipCard AS ThisIsMembershipCard,
				|	DiscountCardKinds.CardType AS CardType
				|INTO CardsKinds
				|FROM
				|	Catalog.DiscountCardKinds AS DiscountCardKinds
				|WHERE
				|	(DiscountCardKinds.CardType = &MixedCardType
				|			OR DiscountCardKinds.CardType = &CardType)
				|	AND DiscountCardKinds.DiscountCardTemplate = &DiscountCardTemplate
				|	AND Not DiscountCardKinds.DeletionMark
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT
				|	DiscountCards.Ref AS Ref,
				|	DiscountCards.Description AS Description,
				|	DiscountCards.CardCodeBarcode AS Barcode,
				|	DiscountCards.CardCodeMagnetic AS MagneticCode,
				|	DiscountCards.CardOwner AS Counterparty,
				|	DiscountCards.Owner AS CardKind,
				|	DiscountCards.Owner.ThisIsMembershipCard AS ThisIsMembershipCard,
				|	DiscountCards.Owner.CardType AS CardType
				|INTO DiscountCards
				|FROM
				|	Catalog.DiscountCards AS DiscountCards
				|		INNER JOIN CardsKinds AS CardsKinds
				|		ON (CardsKinds.Ref = DiscountCards.Owner)
				|			AND (DiscountCards.CardCodeMagnetic = &CardCode)
				|			AND (NOT DiscountCards.DeletionMark)
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT
				|	1 AS Order,
				|	DiscountCards.Ref AS Ref,
				|	DiscountCards.Description AS Description,
				|	DiscountCards.Barcode AS Barcode,
				|	DiscountCards.MagneticCode AS MagneticCode,
				|	DiscountCards.Counterparty AS Counterparty,
				|	DiscountCards.CardKind AS CardKind,
				|	DiscountCards.ThisIsMembershipCard AS ThisIsMembershipCard,
				|	DiscountCards.CardType AS CardType
				|FROM
				|	DiscountCards AS DiscountCards
				|
				|UNION ALL
				|
				|SELECT
				|	2,
				|	VALUE(Catalog.DiscountCards.EmptyRef),
				|	"""",
				|	"""",
				|	&CardCode,
				|	VALUE(Catalog.Counterparties.EmptyRef),
				|	CardsKinds.Ref,
				|	CardsKinds.ThisIsMembershipCard,
				|	CardsKinds.CardType
				|FROM
				|	CardsKinds AS CardsKinds
				|WHERE
				|	Not CardsKinds.Ref In
				|				(SELECT DISTINCT
				|					T.CardKind
				|				IN
				|					DiscountCards AS T)
				|
				|ORDER BY
				|	Order");
				
				Query.SetParameter("MixedCardType", Enums.CardsTypes.Mixed);
				If CodeType = Enums.CardCodesTypes.MagneticCode Then
					Query.SetParameter("CardType", Enums.CardsTypes.Magnetic);
				Else
					Query.SetParameter("CardType", Enums.CardsTypes.Barcode);
				EndIf;
				
				Query.SetParameter("DiscountCardTemplate", DiscountCardTemplate);
				Query.SetParameter("CardCode",             CardCode);
				Query.SetParameter("CodeLength",            StrLen(CardCode));
				
				Result = Query.Execute();
				Selection = Result.Select();
				While Selection.Next() Do
				
					If ValueIsFilled(Selection.Ref) Then
						NewRow = DiscountCardsServer.GetDiscountCardDataStructure();
						FillPropertyValues(NewRow, Selection);
						RegisteredDiscountCards.Add(NewRow);
					Else
						NewRow = DiscountCardsServer.GetDiscountCardDataStructure();
						FillPropertyValues(NewRow, Selection);
						NotRegisteredDiscountCards.Add(NewRow);
					EndIf;
					
				EndDo;
				
			EndDo;
			
			ReturnValue = New Structure("RegisteredDiscountCards, NotRegisteredDiscountCards");
			ReturnValue.RegisteredDiscountCards   = RegisteredDiscountCards;
			ReturnValue.NotRegisteredDiscountCards = NotRegisteredDiscountCards;
		Else
			CardCode = Data[0];
			PrepareCardCodeByDefaultSettings(CardCode);
			ReturnValue = DiscountCardsServer.FindDiscountCardsByMagneticCode(CardCode);
		EndIf;
	Else
		CardCode = Data;
		PrepareCardCodeByDefaultSettings(CardCode);
		ReturnValue = DiscountCardsServer.FindDiscountCardsByMagneticCode(CardCode);
	EndIf;
	
	Return ReturnValue;
	
EndFunction

// Function searches for the discount cards according to data
// that received from magnetic card reader.
//
// Data
//  Parameters - Data array received from the magnetic card reader.
//
// Return
//  value Structure. Structure contains 2 tables of values: Registered
//  discount cards and NotRegisteredDiscountCards.
//
Function FindDiscountCardKindsByDataFromMagneticCardReader(Data, CodeType, KindDiscountCard) Export
	
	SetPrivilegedMode(True);
	
	RegisteredDiscountCards = New Array;
	NotRegisteredDiscountCards = New Array;
	
	If TypeOf(Data) = Type("Array") Then
		ThereIsTemplate = False;
		If ValueIsFilled(KindDiscountCard) Then
			If ValueIsFilled(KindDiscountCard.DiscountCardTemplate) Then
				ThereIsTemplate = True;
				CurTemplate = KindDiscountCard.DiscountCardTemplate;
			Else
				CardCode = Data[0];
				PrepareCardCodeByDefaultSettings(CardCode);
				ReturnValue = New ValueList;
				ReturnValue.Add(CardCode, CardCode);
				
				Return ReturnValue;
			EndIf;
		EndIf;
		
		// Let us decrypt track data according to those templates that are used in the kinds of discount cards.
		DecryptedData = DecryptMagneticCardCode(Data[1][1]);
		
		If DecryptedData <> Undefined Then
			ReturnValue = New ValueList;
			
			For Each CurDataTemplate IN DecryptedData Do
			
				For Each TrackData IN CurDataTemplate.TracksData Do
					If TrackData.Field = Enums.MagneticCardsTemplateFields.Code Then
						If ThereIsTemplate AND CurDataTemplate.Pattern = CurTemplate Then
							ReturnValue.Add(TrackData.FieldValue, ""+TrackData.FieldValue+" ("+CurDataTemplate.Pattern+")");
							Return ReturnValue;
						ElsIf Not ThereIsTemplate Then
							ReturnValue.Add(TrackData.FieldValue, ""+TrackData.FieldValue+" ("+CurDataTemplate.Pattern+")");
						EndIf;
					EndIf;
				EndDo;				
			
			EndDo;
		ElsIf Not ThereIsTemplate Then
			CardCode = Data[0];
			PrepareCardCodeByDefaultSettings(CardCode);
			ReturnValue = New ValueList;
			ReturnValue.Add(CardCode, CardCode);
		Else
			Return New ValueList;
		EndIf;
	Else
		CardCode = Data;
		PrepareCardCodeByDefaultSettings(CardCode);
		ReturnValue = New ValueList;
		ReturnValue.Add(KindDiscountCard, CardCode);
	EndIf;
	
	Return ReturnValue;
	
EndFunction

// Procedure removes the left sign ";" and the right sign "?"
//
Procedure PrepareCardCodeByDefaultSettings(CardCode) Export
	
	// IN many cases data on a magnetic card is written only on the second track.
	// Data on the second track contains a number that is between the prefix and the suffix. 
	// More often there are characters ";" and "?". For example, ";00001234?".
	// IN some cases several blocks separated with a special delimeter character are recorded on the Track 2.
	// More often it is the character "=". For example, ";1234505718812345=1239721320000000?".
	// Remove prefix and suffix. Leave data only of the 1st block.
	// IN more complex cases it is required to use catalog "MagneticCardsTemplates".
	CardCode = TrimAll(CardCode);
	If Left(CardCode, 1) = ";" Then
		CardCode = Mid(CardCode, 2);
	EndIf;
	If Right(CardCode, 1) = "?" Then
		CardCode = Left(CardCode, StrLen(CardCode) - 1);
	EndIf;
	
	SeparatorPosition = Find(CardCode, "=");	
	If SeparatorPosition = 1 Then // For example, ";=1239721320000000?".
		CardCode = Right(CardCode, StrLen(CardCode)-1);
	ElsIf SeparatorPosition > 1 Then
		CardCode = Left(CardCode, SeparatorPosition-1);		
	EndIf;
	
EndProcedure

// Function searches for the discount cards by barcode
//
// Parameters
//  Barcode - String
//
// Return
//  value Structure. Structure contains 2 tables of values: Registered
//  discount cards and NotRegisteredDiscountCards.
//
Function FindDiscountCardsByBarcode(Barcode) Export
	
	Return DiscountCardsServer.FindDiscountCards(Barcode, Enums.CardCodesTypes.Barcode);
	
EndFunction

// Produces data decomposition of the magnetic cards tracks according to templates At the input:
// TracksData - array of rows. Values received from the tracks.
// TracksParameters - The array of structures containing
//  parameters of device settings * Use, Boolean - The sign
//  of using track * TrackNumber, number - track serial number 1-3
//
// Output:
// The array of structures containing the decrypted data to all appropriate templates
// referring to them * Array - templates
//   * Structure - template data
//     - Template, CatalogRef.MagneticCardsTemplates
//     - TracksData, the fields
//       array of all tracks * Structure - Field data
//         - Field
//         - FieldValue
Function DecryptMagneticCardCode(TracksData) Export
	
	If TracksData.Count() = 0 Then
		Return Undefined; // No data
	EndIf;
	
	// Check only the data of the Track 2.
	
	Query = New Query(
	"SELECT
	|	DiscountCardsTemplates.Ref,
	|	DiscountCardsTemplates.Prefix,
	|	DiscountCardsTemplates.Suffix,
	|	DiscountCardsTemplates.CodeLength,
	|	DiscountCardsTemplates.BlocksDelimiter,
	|	DiscountCardsTemplates.FieldLenght,
	|	CASE
	|		WHEN DiscountCardsTemplates.BlockNumber = 0
	|			THEN 1
	|		ELSE DiscountCardsTemplates.BlockNumber
	|	END AS BlockNumber,
	|	DiscountCardsTemplates.NoSizeRestriction,
	|	DiscountCardsTemplates.FirstFieldSymbolNumber
	|FROM
	|	Catalog.DiscountCardsTemplates AS DiscountCardsTemplates
	|WHERE
	|	(DiscountCardsTemplates.CodeLength = &CodeLength
	|			OR DiscountCardsTemplates.NoSizeRestriction)
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(Catalog.DiscountCardsTemplates.EmptyRef),
	|	"";"",
	|	""?"",
	|	0,
	|	"""",
	|	0,
	|	1,
	|	TRUE,
	|0,
	|	0,
	|	"""",
	|	0,
	|	1,
	|	TRUE,
	|	0");
	Query.SetParameter("CodeLength", StrLen(TrimAll(TracksData[1])));
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	TemplatesList = New Array;
	While Selection.Next() Do
		
		// 2-nd stage - Skip the templates that do not match suffix, prefix, delimiter.
		
		If Not CodeCorrespondsToMCTemplate(TracksData, Selection) Then
			Continue;
		EndIf;
		
		TrackData = New Array;
		
		// Search block by number
		DataRow = TracksData[1]; // Process data only from the Track 2.
		Prefix = Selection["Prefix"];
		If Prefix = Left(DataRow, StrLen(Prefix)) Then
			DataRow = Right(DataRow, StrLen(DataRow)-StrLen(Prefix)); // Remove prefix if any
		EndIf;
		Suffix = Selection["Suffix"];
		If Suffix = Right(DataRow, StrLen(Suffix)) Then
			DataRow = Left(DataRow, StrLen(DataRow)-StrLen(Suffix)); // Remove suffix if any
		EndIf;
		
		curBlockNumber = 0;
		While curBlockNumber < Selection.BlockNumber Do
			BlocksDelimiter = Selection["BlocksDelimiter"];
			SeparatorPosition = Find(DataRow, BlocksDelimiter);
			If IsBlankString(BlocksDelimiter) OR SeparatorPosition = 0 Then
				Block = DataRow;
			ElsIf SeparatorPosition = 1 Then
				Block = "";
				DataRow = Right(DataRow, StrLen(DataRow)-1);
			Else
				Block = Left(DataRow, SeparatorPosition-1);
				DataRow = Right(DataRow, StrLen(DataRow)-SeparatorPosition);
			EndIf;
			curBlockNumber = curBlockNumber + 1;
		EndDo;
		
		// Search substring in the block
		FieldValue = Mid(Block, Selection.FirstFieldSymbolNumber, ?(Selection.FieldLenght = 0, StrLen(Block), Selection.FieldLenght));
		
		FieldData = New Structure("Field, FieldValue", Enums.MagneticCardsTemplateFields.Code, FieldValue);
		TrackData.Add(FieldData);
		
		Pattern = New Structure("Template, TracksData", Selection.Ref, TrackData);
		TemplatesList.Add(Pattern);
	EndDo;
	
	If TemplatesList.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	Return TemplatesList;
	
EndFunction

// Determines whether the card code
// matches the Output template:
// TracksData - Array containing rows of the track code. 3 items totally.
// PatternData - a structure containing template data:
// - Suffix
// - Prefix
// - BlocksDelimiter
// - CodeLength
// Output:
// True - code matches template
Function CodeCorrespondsToMCTemplate(TracksData, PatternData)
	// Check only Track 2.
	curRow = TracksData[1];
	If Right(curRow, StrLen(PatternData["Suffix"])) <> PatternData["Suffix"]
		OR Left(curRow, StrLen(PatternData["Prefix"])) <> PatternData["Prefix"]
		OR Find(curRow, PatternData["BlocksDelimiter"]) = 0
		OR (StrLen(curRow) <> PatternData["CodeLength"] AND Not PatternData["NoSizeRestriction"]) Then
		Return False;
	EndIf;
	Return True;
EndFunction

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions


#EndRegion
