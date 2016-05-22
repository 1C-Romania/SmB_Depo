#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ThisForm.Title =  NStr("en = 'Duplicates list by barcode (magnetic code) and card kind'");
							
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	DiscountCards.Ref AS DiscountCard,
		|	DiscountCards.Description,
		|	DiscountCards.CardCodeBarcode,
		|	DiscountCards.CardCodeMagnetic,
		|	DiscountCards.CardOwner,
		|	CASE
		|		WHEN DiscountCards.CardCodeBarcode = &CardCodeBarcode
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS FoundByBarcode,
		|	CASE
		|		WHEN DiscountCards.CardCodeMagnetic = &CardCodeMagnetic
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS FoundByMagneticCode,
		|	DiscountCards.Owner AS KindDiscountCard,
		|	CASE
		|		WHEN DiscountCards.DeletionMark
		|			THEN 4
		|		ELSE 1
		|	END AS Picture
		|FROM
		|	Catalog.DiscountCards AS DiscountCards
		|WHERE
		|	DiscountCards.Owner = &Owner
		|	AND (DiscountCards.CardCodeBarcode = &CardCodeBarcode
		|				AND &CheckBarcode
		|			OR DiscountCards.CardCodeMagnetic = &CardCodeMagnetic
		|				AND &CheckMagneticCode)
		|	AND DiscountCards.Ref <> &Refs";
	
	Query.SetParameter("Owner", Parameters.Owner);
	Query.SetParameter("CardCodeMagnetic", Parameters.CardCodeMagnetic);
	Query.SetParameter("CardCodeBarcode", Parameters.CardCodeBarcode);
	Query.SetParameter("Ref", Parameters.Ref);
	Query.SetParameter("CheckBarcode", (Parameters.Owner.CardType = Enums.CardsTypes.Barcode OR Parameters.Owner.CardType = Enums.CardsTypes.Mixed) AND 
	                                               ValueIsFilled(Parameters.CardCodeBarcode));
	Query.SetParameter("CheckMagneticCode", (Parameters.Owner.CardType = Enums.CardsTypes.Magnetic OR Parameters.Owner.CardType = Enums.CardsTypes.Mixed) AND 
	                                               ValueIsFilled(Parameters.CardCodeMagnetic));
	
	Result = Query.Execute();
	DuplicatingDiscountCardsTables.Load(Result.Unload());
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

// Procedure - event handler Selection in value table DuplicatesList. Opens the form of selected discount card.
//
&AtClient
Procedure DuplicatesListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	TransferParameters = New Structure("Key", Item.CurrentData.DiscountCard);
	TransferParameters.Insert("CloseOnOwnerClose", True);
	
	OpenForm("Catalog.DiscountCards.ObjectForm",
				  TransferParameters, 
				  Item,
				  ,
				  ,
				  ,
				  New NotifyDescription("HandleItemEdit", ThisForm));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure is called when closing discount card form. Opening the form is called from procedure DuplicatesListSelection 
//
&AtClient
Procedure HandleItemEdit(ClosingResult, AdditionalParameters) Export
	Items.DuplicatingDiscountCardsTables.Refresh();
EndProcedure

#EndRegion
