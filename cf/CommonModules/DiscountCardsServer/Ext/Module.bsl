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

// The procedure writes discount card to the
// database on the basis of the transferred structure with the data of a discount card.
//
// Parameters
//  CardDataStructure - A structure with discount card data
//
// Return
//  value CatalogRef.DiscountCards
//
Function RegisterDiscountCard(CardDataStructure) Export
	
	SetPrivilegedMode(True);
	
	MapObject = Catalogs.DiscountCards.CreateItem();
	
	MapObject.CardCodeBarcode  = CardDataStructure.Barcode;
	MapObject.CardCodeMagnetic = CardDataStructure.MagneticCode;
	
	MapObject.Owner   = CardDataStructure.CardKind;
	
	MapObject.CardOwner = CardDataStructure.Counterparty;
	
	MapObject.Description = SetDiscountCardName(MapObject.Owner, MapObject.CardOwner, MapObject.CardCodeBarcode, MapObject.CardCodeMagnetic);
	
	MapObject.Write();
	
	Return MapObject.Ref;
	
EndFunction

// The function returns an empty data structure of discount cards 
//
// No
//  Parameters
//
// Return
//  value Structure - The discount card data
//
Function GetDiscountCardDataStructure() Export
	
	DataStructure = New Structure;
	DataStructure.Insert("Barcode");
	DataStructure.Insert("MagneticCode");
	DataStructure.Insert("Ref");
	DataStructure.Insert("CardKind");
	DataStructure.Insert("CardType");
	DataStructure.Insert("ThisIsMembershipCard");
	DataStructure.Insert("Counterparty");
	
	Return DataStructure;
	
EndFunction

// The function returns the discount card code
// type if it is only used in the discount cards kinds.
//
// No
//  Parameters
//
// Return
//  value Enum.CardCodesTypes / Undefined
//
Function GetDiscountCardBasicCodeType() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT DISTINCT
	|	DiscountCardKinds.CardType AS CardType
	|FROM
	|	Catalog.DiscountCardKinds AS DiscountCardKinds
	|WHERE
	|	Not DiscountCardKinds.DeletionMark");
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	Count = Selection.Count();
	If Count = 0 Then
		Return Undefined;
	ElsIf Count = 1 Then
		Selection.Next();
		If Selection.CardType = Enums.CardsTypes.Barcode Then
			Return Enums.CardCodesTypes.Barcode;
		ElsIf Selection.CardType = Enums.CardsTypes.Magnetic Then
			Return Enums.CardCodesTypes.MagneticCode;
		ElsIf Selection.CardType = Enums.CardsTypes.Mixed Then
			Return Undefined;
		Else
			Return Undefined;
		EndIf;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

#Region SearchDiscountCards

// The procedure returns a partner's discount card if they have only one.
//
// Parameters
//  Partner - CatalogRef.Partners
//
// Return
//  value CatalogRef.DiscountCards / Undefined
//
Function GetDefaultCardForPartner(Counterparty) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT ALLOWED TOP 2
	|	DiscountCards.Ref AS Ref
	|FROM
	|	Catalog.DiscountCards AS DiscountCards
	|WHERE
	|	DiscountCards.CardOwner = &Counterparty
	|	AND Not DiscountCards.DeletionMark");
	
	Query.SetParameter("Counterparty", Counterparty);
	
	Result = Query.Execute();
	Selection = Result.Select();
	If Selection.Count() = 1 Then
		Selection.Next();
		ReplaceableCard = Selection.Ref;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// The function searches for the discount cards
//
// Parameters
//  CardCode - String
//  CodeType - Enum.CardCodesTypes
//
// Return
//  value Structure. IN structure contains 2 tables of values:
//  Registered discount cards and NotRegisteredDiscountCards.
//
Function FindDiscountCards(CardCode, CodeType, Pattern = Undefined) Export
	
	SetPrivilegedMode(True);
	
	RegisteredDiscountCards = New Array;
	NotRegisteredDiscountCards = New Array;
	
	Query = New Query(
	"SELECT ALLOWED DISTINCT
	|	DiscountCardKinds.Ref AS Ref,
	|	DiscountCardKinds.ThisIsMembershipCard AS ThisIsMembershipCard,
	|	DiscountCardKinds.CardType AS CardType,
	|	DiscountCardKinds.DiscountCardTemplate,
	|	DiscountCardKinds.DeletionMark
	|INTO CardsKinds
	|FROM
	|	Catalog.DiscountCardKinds AS DiscountCardKinds
	|WHERE
	|	(DiscountCardKinds.CardType = &MixedCardType
	|			OR DiscountCardKinds.CardType = &CardType)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
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
	|			AND (&FieldNameCardCode = &CardCode)
	|			AND (NOT DiscountCards.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	1 AS Order,
	|	DiscountCards.Ref AS Ref,
	|	DiscountCards.Description AS Description,
	|	DiscountCards.Barcode AS Barcode,
	|	DiscountCards.MagneticCode AS MagneticCode,
	|	DiscountCards.Counterparty AS Counterparty,
	|	DiscountCards.CardKind AS CardKind,
	|	DiscountCards.ThisIsMembershipCard AS ThisIsMembershipCard,
	|	DiscountCards.CardType AS CardType,
	|	VALUE(Catalog.DiscountCardsTemplates.EmptyRef) AS DiscountCardTemplate
	|FROM
	|	DiscountCards AS DiscountCards
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	VALUE(Catalog.DiscountCards.EmptyRef),
	|	"""",
	|	&Barcode,
	|	&MagneticCode,
	|	VALUE(Catalog.Counterparties.EmptyRef),
	|	CardsKinds.Ref,
	|	CardsKinds.ThisIsMembershipCard,
	|	CardsKinds.CardType,
	|	CardsKinds.DiscountCardTemplate
	|FROM
	|	CardsKinds AS CardsKinds
	|WHERE
	|	Not CardsKinds.Ref In
	|				(SELECT DISTINCT
	|					T.CardKind
	|				FROM
	|					DiscountCards AS T)
	|	AND Not CardsKinds.DeletionMark
	|
	|ORDER BY
	|	Order");
	
	Query.SetParameter("MixedCardType", Enums.CardsTypes.Mixed);
	If CodeType = Enums.CardCodesTypes.MagneticCode Then
		Query.SetParameter("CardType", Enums.CardsTypes.Magnetic);
	Else
		Query.SetParameter("CardType", Enums.CardsTypes.Barcode);
	EndIf;
	
	If CodeType = Enums.CardCodesTypes.MagneticCode Then
		
		Query.Text = StrReplace(Query.Text,"&FieldNameCardCode",        "DiscountCards.CardCodeMagnetic");
		
		Query.SetParameter("Barcode",     "");
		Query.SetParameter("MagneticCode", CardCode);
		
	Else
		
		Query.Text = StrReplace(Query.Text,"&FieldNameCardCode",        "DiscountCards.CardCodeBarcode");
		
		Query.SetParameter("Barcode",     CardCode);
		Query.SetParameter("MagneticCode", "");
		
	EndIf;
	
	Query.SetParameter("CardCode",  CardCode);
	Query.SetParameter("CodeLength", StrLen(CardCode));
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
	
		If ValueIsFilled(Selection.Ref) Then
			NewRow = GetDiscountCardDataStructure();
			FillPropertyValues(NewRow, Selection);
			RegisteredDiscountCards.Add(NewRow);
		Else
			CurTemplate = Selection.DiscountCardTemplate;
			// This function is called when you enter a code manually.
			// A user will enter the code manually, so it can not be checked for compliance with the template We do not know what the magnetic track contains.Namely
			// we will give an opportunity to choose any kind of a discount card.
			// If the code is read from the magnetic card, then another function is executed and compliance with the template is checked.
			If CurTemplate.IsEmpty() OR SimpleTemplateCheckingMK(CardCode, CurTemplate) Then
				NewRow = GetDiscountCardDataStructure();
				FillPropertyValues(NewRow, Selection);
				NotRegisteredDiscountCards.Add(NewRow);
			EndIf;
		EndIf;
	
	EndDo;
	
	ReturnValue = New Structure("RegisteredDiscountCards, NotRegisteredDiscountCards");
	ReturnValue.RegisteredDiscountCards   = RegisteredDiscountCards;
	ReturnValue.NotRegisteredDiscountCards = NotRegisteredDiscountCards;
	
	Return ReturnValue;
	
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
Function SimpleTemplateCheckingMK(CardCode, PatternData)
	// Check only one track.
	curRow = CardCode;
	If (NOT PatternData.NoSizeRestriction AND StrLen(curRow) > PatternData.CodeLength)
		OR (PatternData.FieldLenght > 0 AND StrLen(curRow) > PatternData.FieldLenght)
	Then
		Return False;
	EndIf;
	Return True;
EndFunction

// The function searches for discount cards by magnetic code
//
// Magnetic
//  code Parameters - String
//
// Return
//  value Structure. IN structure contains 2 tables of values:
//  Registered discount cards and NotRegisteredDiscountCards.
//
Function FindDiscountCardsByMagneticCode(MagneticCode) Export
	
	Return FindDiscountCards(MagneticCode, Enums.CardCodesTypes.MagneticCode);
	
EndFunction

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

#EndRegion
