
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Items.Characteristic.Visible = Parameters.ShowInformationAboutDiscountsOnRow;
	Items.ProductsAndServices.Visible   = Parameters.ShowInformationAboutDiscountsOnRow;
	
	Items.ManualDiscountAmount.Visible = GetFunctionalOption("UseDiscountsMarkups");
	
	Currency = "RUB";
	
	If ValueIsFilled(Parameters.Title) Then
		AutoTitle = False;
		Title = Parameters.Title;
	EndIf;
	
	If Parameters.ShowInformationAboutDiscountsOnRow Then
		
		ProductsAndServices   = Parameters.CurrentData.ProductsAndServices;
		Characteristic = Parameters.CurrentData.Characteristic;
		
		// Total amount of discount includes the amount of automatic and manual discount.
		AutoDiscountAmount   = 0;
		ManualDiscountAmount = Parameters.CurrentData.ManualDiscountAmount;
		
		Filter = New Structure("ConnectionKey", Parameters.CurrentData.ConnectionKey);
		For Each VTRowDiscountsMarkups IN Parameters.Object.DiscountsMarkups.FindRows(Filter) Do
			
			NewRow = AutomaticDiscounts.Add();
			FillPropertyValues(NewRow, VTRowDiscountsMarkups);
			If Parameters.CurrentData.AmountWithoutDiscount <> 0 Then
				NewRow.Percent = 100 * VTRowDiscountsMarkups.Amount / Parameters.CurrentData.AmountWithoutDiscount;
			EndIf;
			
			AutoDiscountAmount = AutoDiscountAmount + NewRow.Amount;
			
		EndDo;
		
		DiscountAmount       = AutoDiscountAmount + ManualDiscountAmount;
		
	Else
		
		AutoDiscountAmount   = Parameters.Object.Products.Total("AutomaticDiscountAmount");
		ManualDiscountAmount = Parameters.Object.Products.Total("ManualDiscountAmount");
		DiscountAmount       = AutoDiscountAmount + ManualDiscountAmount;
		
	EndIf;
	
	Parameters.Property("MinimumPrice", MinimumPrice);
	
	// Information can be displayed only after direct calculation of discounts in the document.
	// After you close the form, the information will not be saved.
	If ValueIsFilled(Parameters.AddressDiscountsAppliedInTemporaryStorage) Then
		
		AppliedDiscounts = GetFromTempStorage(Parameters.AddressDiscountsAppliedInTemporaryStorage);
		
		If Parameters.ShowException Then
			DisplayLabelExceptions();
		EndIf;
	
		If Parameters.ShowInformationAboutRowCalculationDiscount Then 
			FormInformationOnCalculatingDiscountsByRow(AppliedDiscounts, Parameters.CurrentData.ConnectionKey, AutomaticDiscounts.Unload());
		EndIf;
		
	EndIf;
	
	Items.SharedUseVersionText.Title = String(Constants.DiscountsMarkupsSharedUsageOptions.Get());
	
EndProcedure

&AtClient
Procedure ExpandTreeToConditionsRecursively(TreeRow, FormItem)
	
	ItemCollection = TreeRow.GetItems();
	For Each Item IN ItemCollection Do
	
		If Item.Expand Then
			FormItem.Expand(Item.GetID());
			ExpandTreeToConditionsRecursively(Item, FormItem);
		EndIf;
	
	EndDo;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ExpandTreeToConditionsRecursively(InformationAboutRowDiscountsCalculation, Items.InformationAboutRowDiscountsCalculation);
	
EndProcedure

&AtServer
Procedure CalculateInformationOnCalculatingDiscountsByRow(IncomingDiscountsTree, DiscountsTree, ConnectionKey, TableAutomaticDiscounts)
	
	For Each TreeRow IN DiscountsTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			CalculateInformationOnCalculatingDiscountsByRow(IncomingDiscountsTree, TreeRow, ConnectionKey, TableAutomaticDiscounts);
			
			TreeRow.PictureIndex = DiscountsMarkupsServer.GetPictureIndexForGroup(TreeRow);
			TreeRow.Value = TreeRow.DiscountMarkup;
			TreeRow.Expand = True;
			
			For Each Str IN TreeRow.Rows Do
				If Str.Acts Then
					TreeRow.Acts        = True;
					TreeRow.ConditionsFulfilled = True;
					Break;
				EndIf;
			EndDo;
			
			TreeRow.AutomaticDiscountAmount = TreeRow.Rows.Total("AutomaticDiscountAmount");
			
		Else
			
			TreeRow.PictureIndex = DiscountsMarkupsServer.GetPictureIndexForDiscount(TreeRow);
			TreeRow.Value = TreeRow.DiscountMarkup;
			
			AllConditionsFulfilled = True;
			For Each RowCondition IN TreeRow.ConditionsParameters.TableConditions Do
				
				NewRowCondition = TreeRow.Rows.Add();
				NewRowCondition.Value       = RowCondition.AssignmentCondition;
				NewRowCondition.ThisCondition     = True;
				
				If RowCondition.RestrictionArea = Enums.DiscountMarkupRestrictionAreasVariants.AtRow Then
					FoundConditionsCheckingTableRows = TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.Find(ConnectionKey, "ConnectionKey");
					If FoundConditionsCheckingTableRows <> Undefined Then
						ColumnName = TreeRow.ConditionsParameters.ConditionsByLine.MatchConditionTableColumnsWithConditionsCheckingTable.Get(RowCondition.AssignmentCondition);
						If ColumnName <> Undefined Then
							NewRowCondition.Acts = FoundConditionsCheckingTableRows[ColumnName];
						EndIf;
					Else
						
					EndIf;
				Else
					NewRowCondition.Acts = RowCondition.Completed;
				EndIf;
				
				NewRowCondition.PictureIndex = -1;
				
				NewRowCondition.ConditionsFulfilled = NewRowCondition.Acts;
				If Not NewRowCondition.Acts Then
					AllConditionsFulfilled = False;
				EndIf;
				
			EndDo;
			
			If AllConditionsFulfilled Then
				TreeRow.Acts = True;
				TreeRow.ConditionsFulfilled = True;
				
				If IncomingDiscountsTree.TableDiscountsMarkups.FindRows(New Structure("ConnectionKey, DiscountMarkup", ConnectionKey, TreeRow.DiscountMarkup)).Count() = 0 Then
					TreeRow.NotAppliedUnderSharedUseTerms = True;
				EndIf;
				
				SearchStructure = New Structure("DiscountMarkup", TreeRow.DiscountMarkup);
				SearchRows = TableAutomaticDiscounts.FindRows(SearchStructure);
				TreeRow.AutomaticDiscountAmount = 0;
				For Each SearchString IN SearchRows Do
					TreeRow.AutomaticDiscountAmount = TreeRow.AutomaticDiscountAmount + SearchString.Amount;
					If SearchString.LimitedByMinimumPrice Then
						TreeRow.LimitedByMinimumPrice = True;
					EndIf;
				EndDo;
				
			Else
				TreeRow.ConditionsFulfilled = False;
			EndIf;
			
			For Each RowCondition IN TreeRow.Rows Do
				RowCondition.NotAppliedUnderSharedUseTerms = TreeRow.NotAppliedUnderSharedUseTerms;
				RowCondition.DiscountApplied = TreeRow.Acts;
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure // CalculateInformationOnCalculatingDiscountsByDocument()

&AtServer
Procedure FormInformationOnCalculatingDiscountsByRow(IncomingDiscountsTree, ConnectionKey, TableAutomaticDiscounts)
	
	DiscountsTree = IncomingDiscountsTree.DiscountsTree.Copy();
	
	DiscountsTree.Columns.Add("PictureIndex",   New TypeDescription("Number"));
	DiscountsTree.Columns.Add("Acts",        New TypeDescription("Boolean"));
	DiscountsTree.Columns.Add("ConditionsFulfilled", New TypeDescription("Boolean"));
	DiscountsTree.Columns.Add("NotAppliedUnderSharedUseTerms", New TypeDescription("Boolean"));
	DiscountsTree.Columns.Add("Expand",  New TypeDescription("Boolean"));
	DiscountsTree.Columns.Add("ThisCondition",     New TypeDescription("Boolean"));
	DiscountsTree.Columns.Add("Value",       New TypeDescription("CatalogRef.AutomaticDiscounts, CatalogRef.DiscountsMarkupsProvidingConditions"));
	DiscountsTree.Columns.Add("AutomaticDiscountAmount", New TypeDescription("Number"));
	DiscountsTree.Columns.Add("LimitedByMinimumPrice", New TypeDescription("Boolean"));
	DiscountsTree.Columns.Add("DiscountApplied", New TypeDescription("Boolean"));
	
	CalculateInformationOnCalculatingDiscountsByRow(IncomingDiscountsTree, DiscountsTree, ConnectionKey, TableAutomaticDiscounts);
	
	ValueToFormAttribute(DiscountsTree, "InformationAboutRowDiscountsCalculation");
	
EndProcedure // FormInformationAboutCalculatingDiscountsByDocument()

&AtClient
Procedure InformationAboutRowDiscountsCalculationValueStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure InformationAboutRowDiscountsCalculationValueClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////////
// Office

&AtServer
Procedure DisplayLabelExceptions()
	
	
	
EndProcedure














