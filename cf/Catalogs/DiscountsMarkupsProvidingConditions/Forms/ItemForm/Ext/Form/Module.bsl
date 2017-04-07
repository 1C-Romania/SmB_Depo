
&AtClient
Var CachedValues;

#Region ProgramInterface

#EndRegion

#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	ThisForm.ReadOnly = Not AllowedEditDocumentPrices;
	
	ObjectVersioning.OnCreateAtServer(ThisForm);
	
	//AdditionalProductsAndServicesColumns = SettingsValueRepeatUse.ReceiveConstantValue("AdditionalColumnOnProductsAndServicesRepresentation");
	ReceiveConfigurationRestrictions();
	
	DiscountsMarkupsServerOverridable.GetDiscountProvidingConditionsValuesList(Items.AssignmentCondition.ChoiceList);
	
	AssignmentConditionOnChangeAtServer();
	ApplicationCriterionForSalesVolumeOnChangeAtServer();
	
	If Not ValueIsFilled(Object.Ref) Then
		Object.Description = FormAutoNamingAtServer();
	Else
		FormAutoNamingAtServer();
	EndIf;
	
	FillSignsInTP();
	
	For Each NameVariant IN Items.Description.ChoiceList Do
		If Object.Description = NameVariant.Value Then
			UsedAutoDescription = True;
		EndIf;
	EndDo;
	
	Modified = False;
	
	SmallBusinessClientServer.SetPictureForComment(Items.CommentGroup, Object.Comment);
	
	// Handler of the Additional reports and data processors subsystem
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillSignsInTP();
	
	DiscountRecipientTypePrevious = DiscountRecipientType;
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

// The procedure fills in values of the CharacteristicsUsed and IsFolder attributes (added in form)
//
&AtServer
Procedure FillSignsInTP()

	For Each CurrentRow IN Object.PurchaseKit Do
		CurrentRow.CharacteristicsAreUsed = CurrentRow.ProductsAndServices.UseCharacteristics;
		CurrentRow.IsFolder = CurrentRow.ProductsAndServices.IsFolder;
	EndDo;
	For Each CurrentRow IN Object.SalesFilterByProductsAndServices Do
		CurrentRow.CharacteristicsAreUsed = CurrentRow.ProductsAndServices.UseCharacteristics;
		CurrentRow.IsFolder = CurrentRow.ProductsAndServices.IsFolder;
	EndDo;

EndProcedure

// Procedure - BeforeWrite event handler.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	UpdateAutoNaming(Modified);
	
EndProcedure

// Procedure - handler of the AfterWriteAtServer event.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillSignsInTP();
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("AssignmentCondition_Record");
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

// Procedure - handler of the OnChange event of the RestrictionCurrency item.
//
&AtClient
Procedure RestrictionCurrencyOnChange(Item)
	UpdateAutoNaming(True);
EndProcedure

// Procedure - handler of the OnChange event of AssignmentConditionValue form item.
//
&AtClient
Procedure AssignmentConditionValueOnChange(Item)
	UpdateAutoNaming(True);
EndProcedure

// Procedure - handler of the AutoPick event of the Name item.
//
&AtClient
Procedure NameAutoFilter(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		FormAutoNamingAtClient();
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange item Name.
//
&AtClient
Procedure DescriptionOnChange(Item)
	
	DescriptionChangedByUser = True;
	
EndProcedure

// Procedure - handler of the OnChange event of the RestrictionField item.
//
&AtClient
Procedure RestrictionAreaOnChange(Item)
	UpdateAutoNaming(True);
EndProcedure

// Procedure - handler of the OnChange event of the ComparisonType item.
//
&AtClient
Procedure ComparisonTypeOnChange(Item)
	UpdateAutoNaming(True);
EndProcedure

// Procedure - handler of the OnChange event of AssignmentCondition form item.
//
&AtClient
Procedure AssignmentConditionOnChange(Item)
	
	AssignmentConditionOnChangeAtServer();
	Object.Description = "";
	
	UpdateAutoNaming(True);
	
EndProcedure

// server part the AssignmentConditionOnChange procedure - handler of the OnChange event of AssignmentCondition form item.
//
&AtServer
Procedure AssignmentConditionOnChangeAtServer()
	
	Items.ForOneTimeSalesVolume.Visible             = (Object.AssignmentCondition = Enums.DiscountsMarkupsProvidingConditions.ForOneTimeSalesVolume);
	Items.ForKitPurchase.Visible                = (Object.AssignmentCondition = Enums.DiscountsMarkupsProvidingConditions.ForKitPurchase);
	
	Items.RestrictionArea.Enabled = True;
	
EndProcedure

// Procedure - handler of the OnChange event of the UseRestrictionCriterionForSalesVolume form item.
//
&AtClient
Procedure ApplicationCriterionForSalesVolumeOnChange(Item)
	
	ApplicationCriterionForSalesVolumeOnChangeAtServer();
	
	UpdateAutoNaming(True);
	
EndProcedure

// Server part the ApplicationCriterionForSalesVolumeOnChange procedure - handler of the OnChange event of the UseRestrictionCriterionForSalesVolume form item.
//
&AtServer
Procedure ApplicationCriterionForSalesVolumeOnChangeAtServer()
	
	If Object.UseRestrictionCriterionForSalesVolume = Enums.DiscountMarkupUseLimitCriteriaForSalesVolume.Quantity Then
		
		Items.RestrictionCurrency.Visible = False;
		
	Else
		
		Items.RestrictionCurrency.Visible = UsedCurrencies;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.CommentGroup, Object.Comment);
	
EndProcedure

#EndRegion

#Region TableItemsEventHandlersFormsPurchaseKit

// Procedure - handler of the OnChange event in the ProductsAndServices column TP PurchaseKit form.
//
&AtClient
Procedure PurchaseKitProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.PurchaseKit.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity= 1;
	TabularSectionRow.CharacteristicsAreUsed = StructureData.CharacteristicsAreUsed;
	TabularSectionRow.IsFolder = StructureData.IsFolder;
	
EndProcedure

// Procedure - handler of the AfterDeletion event TP PurchaseKit form.
//
&AtClient
Procedure PurchaseKitAfterDeleteRow(Item)
	
	Object.Description = FormAutoNamingAtClient();
	
EndProcedure

// Procedure - handler of the OnEditEnd event TP PurchaseKit form.
//
&AtClient
Procedure PurchaseKitOnEditEnd(Item, NewRow, CancelEdit)
	
	Object.Description = FormAutoNamingAtClient();
	
EndProcedure

#EndRegion

#Region TableItemsEventHandlersSalesFilterByProductsAndServices

// Procedure - handler of the OnEditEnd event TP SalesSelectionByProductsAndServices form.
//
&AtClient
Procedure FilterSalesByProductsAndServicesOnEditEnd(Item, NewRow, CancelEdit)
	
	Object.Description = FormAutoNamingAtClient();
	
EndProcedure

// Procedure - handler of the AfterDeletion event TP SalesFilterByProductsAndServices form.
//
&AtClient
Procedure FilterSalesByProductsAndServicesAfterDeletion(Item)
	
	Object.Description = FormAutoNamingAtClient();
	
EndProcedure

// Procedure - handler of the OnChange event in the  ProductsAndServices column TP SalesFilterByProductsAndServices form.
//
&AtClient
Procedure FilterSalesByProductsAndServicesProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.SalesFilterByProductsAndServices.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.CharacteristicsAreUsed = StructureData.CharacteristicsAreUsed;
	TabularSectionRow.IsFolder = StructureData.IsFolder;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure defines currency use.
//
&AtServer
Procedure ReceiveConfigurationRestrictions()

	UsedCurrencies = GetFunctionalOption("CurrencyTransactionsAccounting");

EndProcedure

// This function returns a brief content of the tabular section in row form.
//
&AtClient
Function TabularSectionDescriptionClient(TableName, AttributeName, ItemCount = 0)

	TableLongDesc = "";
	
	ItemNumber = 0;
	For Each TableElement IN Object[TableName] Do
		
		ItemNumber = ItemNumber + 1;
		If Not ItemCount = 0 AND (ItemCount + 1) = ItemNumber Then
			TableLongDesc = TableLongDesc + "... ,";
		ElsIf Not ItemCount = 0 AND (ItemCount + 1) < ItemNumber Then
			Break;
		Else
			TableLongDesc = TableLongDesc + String(TableElement[AttributeName]) + ", ";
		EndIf;
		
	EndDo;
	
	If Not TableLongDesc = "" Then
	
		TableLongDesc = Left(TableLongDesc, StrLen(TableLongDesc) - 2);
	
	EndIf;
	
	Return TableLongDesc;

EndFunction

// This function returns a brief content of the tabular section in row form.
//
&AtServer
Function TabularSectionDescriptionServer(TableName, AttributeName, ItemCount = 0)

	TableLongDesc = "";
	
	ItemNumber = 0;
	For Each TableElement IN Object[TableName] Do
		
		ItemNumber = ItemNumber + 1;
		If Not ItemCount = 0 AND (ItemCount + 1) = ItemNumber Then
			TableLongDesc = TableLongDesc + "... ,";
		ElsIf Not ItemCount = 0 AND (ItemCount + 1) < ItemNumber Then
			Break;
		Else
			TableLongDesc = TableLongDesc + String(TableElement[AttributeName]) + " ,";
		EndIf;
		
	EndDo;
	
	If Not TableLongDesc = "" Then
	
		TableLongDesc = Left(TableLongDesc, StrLen(TableLongDesc) - 2);
	
	EndIf;
	
	Return TableLongDesc;

EndFunction

// The procedure updates the name if the user did not change it manually.
//
&AtClient
Procedure UpdateAutoNaming(Refresh = True)
	
	If Not ValueIsFilled(Object.Description) OR (Refresh AND UsedAutoDescription AND Not DescriptionChangedByUser) Then
		Object.Description = FormAutoNamingAtClient();
		UsedAutoDescription = True;
	EndIf;
	
EndProcedure

// The function returns generated auto naming.
//
&AtClient
Function FormAutoNamingAtClient()
	
	Items.Description.ChoiceList.Clear();
	
	If Object.AssignmentCondition = PredefinedValue("Enum.DiscountsMarkupsProvidingConditions.ForOneTimeSalesVolume") Then
		DescriptionString = ""+?(Object.UseRestrictionCriterionForSalesVolume = PredefinedValue("Enum.DiscountMarkupUseLimitCriteriaForSalesVolume.Quantity"), "Count-in", Object.UseRestrictionCriterionForSalesVolume) + " " + 
		?(Object.RestrictionArea = PredefinedValue("Enum.DiscountMarkupRestrictionAreasVariants.InDocument"),NStr("en='in document';ru='в документе'"),NStr("en='In line';ru='в строке'")) + " "+Object.ComparisonType + " "+Object.RestrictionConditionValue + 
		?(Object.UseRestrictionCriterionForSalesVolume = PredefinedValue("Enum.DiscountMarkupUseLimitCriteriaForSalesVolume.Quantity"), NStr("en=' unit';ru=' ед'"), " "+Object.RestrictionCurrency);
		If Object.SalesFilterByProductsAndServices.Count() > 0 Then
			DescriptionString = DescriptionString + ": " + TabularSectionDescriptionClient("SalesFilterByProductsAndServices", "ProductsAndServices");
		EndIf;
	ElsIf Object.AssignmentCondition = PredefinedValue("Enum.DiscountsMarkupsProvidingConditions.ForKitPurchase") Then
		DescriptionString = NStr("en='Kit:';ru='Комплект:'");
		DescriptionString = DescriptionString + " " + TabularSectionDescriptionClient("PurchaseKit", "ProductsAndServices");
	EndIf;
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
	Return DescriptionString;

EndFunction

// The function returns generated auto naming.
//
&AtServer
Function FormAutoNamingAtServer()
	
	Items.Description.ChoiceList.Clear();
	
	If Object.AssignmentCondition = Enums.DiscountsMarkupsProvidingConditions.ForOneTimeSalesVolume Then
		DescriptionString = ""+?(Object.UseRestrictionCriterionForSalesVolume = Enums.DiscountMarkupUseLimitCriteriaForSalesVolume.Quantity, "Count-in", Object.UseRestrictionCriterionForSalesVolume) + " " + 
		?(Object.RestrictionArea = Enums.DiscountMarkupRestrictionAreasVariants.InDocument,NStr("en='in document';ru='в документе'"),NStr("en='In line';ru='в строке'")) + " "+Object.ComparisonType + " "+Object.RestrictionConditionValue + 
		?(Object.UseRestrictionCriterionForSalesVolume = Enums.DiscountMarkupUseLimitCriteriaForSalesVolume.Quantity, NStr("en=' unit';ru=' ед'"), " "+Object.RestrictionCurrency);
		If Object.SalesFilterByProductsAndServices.Count() > 0 Then
			DescriptionString = DescriptionString + ": " + TabularSectionDescriptionServer("SalesFilterByProductsAndServices", "ProductsAndServices");
		EndIf;
	ElsIf Object.AssignmentCondition = Enums.DiscountsMarkupsProvidingConditions.ForKitPurchase Then
		DescriptionString = NStr("en='Kit:';ru='Комплект:'");
		DescriptionString = DescriptionString + " " + TabularSectionDescriptionServer("PurchaseKit", "ProductsAndServices");
	EndIf;
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
	Return DescriptionString;

EndFunction

#EndRegion

#Region CommonUseProceduresAndFunctions

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	StructureData.Insert("CharacteristicsAreUsed", StructureData.ProductsAndServices.UseCharacteristics);
	StructureData.Insert("IsFolder", StructureData.ProductsAndServices.IsFolder);
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

#EndRegion