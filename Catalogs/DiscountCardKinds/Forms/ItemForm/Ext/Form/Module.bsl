#Region CommonUseProceduresAndFunctions

&AtClient
// Returns the text presentation of an interval.
//
Function GetIntervalView(TabularSection, CurrentRow)

	MaxLowerLimit = Undefined;
	NextString = Undefined;
	For Each TSRow IN TabularSection Do
		If (MaxLowerLimit = Undefined Or MaxLowerLimit >= TSRow.LowerBound)
		   AND CurrentRow.LowerBound <= TSRow.LowerBound
		   AND TSRow <> CurrentRow Then
			NextString = TSRow;
			MaxLowerLimit = TSRow.LowerBound;
		EndIf;
	EndDo;

	If NextString = Undefined Then
		IntervalView = "from " + TrimAll(CurrentRow.LowerBound) + " " + AccountingCurrency;
	ElsIf CurrentRow.LowerBound = NextString.LowerBound Then
		IntervalView = "ERROR: such lower limit already exists!";
	Else
		IntervalView = "from " + TrimAll(CurrentRow.LowerBound) + " to " + TrimAll(NextString.LowerBound) + " " + AccountingCurrency;
	EndIf;

	Return IntervalView;

EndFunction // GetIntervalView()

// The procedure updates a value in the column "IntervalView" of spreadsheet part "AccumulativeDiscountsThresholds".
//
&AtClient
Procedure UpdateAllRowsPresentation()

	For Each CurRow IN Object.ProgressiveDiscountLimits Do
		CurRow.IntervalView = GetIntervalView(Object.ProgressiveDiscountLimits, CurRow);
	EndDo;

EndProcedure

#EndRegion

#Region ProceduresFormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.DiscountKindForDiscountCards) Then
		Object.DiscountKindForDiscountCards = PredefinedValue("Enum.DiscountKindsForDiscountCards.FixedDiscount");
	EndIf;
	If Not ValueIsFilled(Object.CardType) Then
		Object.CardType = Enums.CardsTypes.Barcode;
	EndIf;	
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	
	ThisForm.ReadOnly = Not AllowedEditDocumentPrices;
	AccountingCurrency = Constants.AccountingCurrency.Get();
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	VisibleManagementAtServer();
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	VisibleManagementAtServer();
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	UpdateAllRowsPresentation();
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	UpdateAllRowsPresentation();
	
EndProcedure

#EndRegion

#Region ProceduresElementFormEventsHandlers

// Procedure - event handler OnChange item CardType.
//
&AtClient
Procedure CardTypeOnChange(Item)
	
	Items.DiscountCardTemplate.Visible = (Object.CardType <> PredefinedValue("Enum.CardsTypes.Barcode"));
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

// Procedure - event handler OnChange item DiscountKindForDiscountCards.
//
&AtClient
Procedure DiscountKindForDiscountCardsOnChange(Item)
	
	VisibleManagementAtServer();
	
EndProcedure

// Procedure - event  handler OnChange item PeriodKind.
//
&AtClient
Procedure PeriodKindOnChange(Item)
	
	PeriodKindOnChangeAtServer();
	
EndProcedure

// Procedure - events handler OnChange item PeriodKind (server part).
//
&AtServer
Procedure PeriodKindOnChangeAtServer()
	
	Items.Periodicity.Visible = (Object.PeriodKind <> PredefinedValue("Enum.PeriodKindsForProgressiveDiscounts.EntirePeriod"));
	If Not ValueIsFilled(Object.Periodicity) AND Items.Periodicity.Visible Then
		Object.Periodicity = PredefinedValue("Enum.Periodicity.Year");
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresSpreadsheetPartEventsHandlers

// Procedure - events handler "OnEditingFinish" rows in the SP "AccumulativeDiscountsThresholds".
//
&AtClient
Procedure ProgressiveDiscountLimitOnEditEnd(Item, NewRow, CancelEdit)
	
	// After inputing the string, sort SP in ascending order until the lower limit.
	Object.ProgressiveDiscountLimits.Sort("LowerBound");
	UpdateAllRowsPresentation();
	
EndProcedure

// Procedure - events handler "OnChange" for column "LowerLimit" rows in SP "AccumulativeDiscountsThresholds".
//
&AtClient
Procedure ProgressiveDiscountLimitsLowerBoundOnChange(Item)
	
	CurRowItem = Items.ProgressiveDiscountLimits.CurrentData;
	CurRowItem.IntervalView = GetIntervalView(Object.ProgressiveDiscountLimits, CurRowItem);
	
EndProcedure

// Procedure - events handler "AfterDeletion" SP "AccumulativeDiscountsThresholds".
//
&AtClient
Procedure ProgressiveDiscountLimitsAfterDeleteRow(Item)
	
	UpdateAllRowsPresentation();
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForFormAppearanceManagement

// The procedure is intended for management of form items visible depending on the kind and type of discount card.
&AtServer
Procedure VisibleManagementAtServer()

	If Object.DiscountKindForDiscountCards = PredefinedValue("Enum.DiscountKindsForDiscountCards.ProgressiveDiscount") AND
		Object.PeriodKind.IsEmpty() Then
		Object.PeriodKind = PredefinedValue("Enum.PeriodKindsForProgressiveDiscounts.EntirePeriod");
	EndIf;
	
	Items.Discount.Visible = (Object.DiscountKindForDiscountCards = PredefinedValue("Enum.DiscountKindsForDiscountCards.FixedDiscount"));
	TheseAreAccumulativeDiscounts = (Object.DiscountKindForDiscountCards = PredefinedValue("Enum.DiscountKindsForDiscountCards.ProgressiveDiscount"));
	Items.ProgressiveDiscountLimits.Visible = TheseAreAccumulativeDiscounts;
	Items.PeriodKind.Visible = TheseAreAccumulativeDiscounts;
	Items.Periodicity.Visible = (Object.PeriodKind <> PredefinedValue("Enum.PeriodKindsForProgressiveDiscounts.EntirePeriod")) AND TheseAreAccumulativeDiscounts;
	Items.DiscountCardTemplate.Visible = (Object.CardType <> PredefinedValue("Enum.CardsTypes.Barcode"));
	
EndProcedure

#EndRegion