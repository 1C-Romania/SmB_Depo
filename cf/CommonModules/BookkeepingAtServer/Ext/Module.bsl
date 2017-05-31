Function GetBookkeepingReportInitializationData() Export
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("Company",DefaultValuesAtServer.GetDefaultCompany());
	ReturnStructure.Insert("FinancialYear",DefaultValuesAtServer.GetDefaultFinancialYear());
	Return New FixedStructure(ReturnStructure);
	
EndFunction	

Function GetBookeepingParametersArray() Export
	
	BookkeepingParametersArray = New Array;
	BookkeepingParametersArray.Add("Company");
	BookkeepingParametersArray.Add("Account");
	BookkeepingParametersArray.Add("CashDesk");
	BookkeepingParametersArray.Add("DuesAndDebtsPeriods");
	BookkeepingParametersArray.Add("PartialJournal");
	BookkeepingParametersArray.Add("FinancialYear");
	BookkeepingParametersArray.Add("ShowClosePeriodRecords");
	BookkeepingParametersArray.Add("OutputPageTotals");
	BookkeepingParametersArray.Add("ExtDimensionsArray");

	
	Return New FixedArray(BookkeepingParametersArray);
	
EndFunction

Function AccountsCard_UpdateDependencesOnAccount(Val Account, SettingsComposer, Val FormUUID, DataCompositionSchemaAdress) Export
		
	If ValueIsNotFilled(Account) Then
		NumberOfExtDimensions =0;
		AccountCurrency = False;
	Else
		NumberOfExtDimensions = Account.ExtDimensionTypes.Count();
		AccountCurrency = Account.Currency;
	EndIf;
	
	FiltersListToUnset = New ValueList();
	
	DataCompositionSchema = Reports.AccountsCard.GetTemplate("MainDataCompositionSchema");
	
	FieldsArray = New Array();
	FieldsArray.Add(DataCompositionSchema.DataSets[0].Items[0]);
	FieldsArray.Add(DataCompositionSchema.DataSets[0].Items[1]);
	FieldsArray.Add(DataCompositionSchema.DataSets[0]);
		
	For Each DataSet In FieldsArray Do
		
		FoundField = DataSet.Fields.Find("Currency");
		If FoundField <> Undefined Then
			
			If NOT FoundField.UseRestriction.Condition AND NOT AccountCurrency
				AND FiltersListToUnset.FindByValue(FoundField.Field) = Undefined Then
				FiltersListToUnset.Add(FoundField.Field);
			EndIf;	
			
			FoundField.UseRestriction.Condition = NOT AccountCurrency;
			FoundField.AttributeUseRestriction.Condition = NOT AccountCurrency;
			
		EndIf;	
		
		For i = 1 To Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount Do
			
			IsExtDimAvailable = (NumberOfExtDimensions>=i);
			
			FoundField = DataSet.Fields.Find("ExtDimension"+i);
			If FoundField <> Undefined Then
				
				WasAdded = False;
				If NOT FoundField.UseRestriction.Condition AND NOT IsExtDimAvailable 
					AND FiltersListToUnset.FindByValue(FoundField.Field) = Undefined Then
					FiltersListToUnset.Add(FoundField.Field);
					WasAdded = True;
				EndIf;	
				
				FoundField.UseRestriction.Condition = NOT IsExtDimAvailable;
				FoundField.AttributeUseRestriction.Condition = NOT IsExtDimAvailable;
				
				If IsExtDimAvailable Then
					FoundField.Title = Account.ExtDimensionTypes[i-1].ExtDimensionType.Description;
					FoundField.ValueType = Account.ExtDimensionTypes[i-1].ExtDimensionType.ValueType;
					
				EndIf;	
				
			EndIf;	
			
		EndDo;	
		
	EndDo;	
	

	DataCompositionSchemaAdress = PutToTempStorage(DataCompositionSchema, FormUUID);	
	
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	SettingsComposer.Refresh();	
	
	ExpandFilters = False;
	
	FiltersToDeleteArray = New Array;      
	UserSettingsToDeleteArray = New Array;    
	For Each FilterItem In SettingsComposer.Settings.Filter.Items Do
		
		AvailableField = SettingsComposer.Settings.FilterAvailableFields.FindField(FilterItem.LeftValue);  
		UserSettingValue = SettingsComposer.UserSettings.Items.Find(FilterItem.UserSettingID);  
		
		If AvailableField = Undefined Then           
			FiltersToDeleteArray.Add(FilterItem);      
			UserSettingsToDeleteArray.Add(UserSettingValue);  
			ExpandFilters = True;                         
		EndIf;	
		
		If NOT FilterItem.Use Then
			Continue;
		EndIf;	
		
		FilterItemLeftValueAsString = String(FilterItem.LeftValue);
		FoundDot = Find(FilterItemLeftValueAsString,".");
		If FoundDot>0 Then
			FilterItemLeftValueAsString = Left(FilterItemLeftValueAsString,FoundDot-1);	
		EndIf;	
		
		If FiltersListToUnset.FindByValue(FilterItemLeftValueAsString)<> Undefined
			OR (AvailableField <> Undefined AND NOT AvailableField.ValueType.ContainsType(TypeOf(FilterItem.RightValue))) Then    
			
			FilterItem.Use = False;
			
			If UserSettingValue <> Undefined Then 
				UserSettingValue.Use = False;                             
				UserSettingValue.UserSettingPresentation = "";                   
				UserSettingValue.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;       
				FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Normal;                    
				FilterItem.RightValue = AvailableField.ValueType.AdjustValue(FilterItem.RightValue);     
				UserSettingValue.RightValue = AvailableField.ValueType.AdjustValue(UserSettingValue.RightValue);     
			EndIf;                                                                                     

			ExpandFilters = True;
			
		EndIf;	
		
	EndDo;	
	
	For Each FiltersToDeleteArrayItem In FiltersToDeleteArray Do      
		SettingsComposer.Settings.Filter.Items.Delete(FilterItem);   
	EndDo;                                                            
	
	For Each UserSettingsToDeleteArrayItem In UserSettingsToDeleteArray Do   
		UserSettingsToDeleteArrayItem.Use = False;                           
		UserSettingsToDeleteArrayItem.UserSettingID = "";                    
		UserSettingsToDeleteArrayItem.RightValue = Undefined;                 
		UserSettingsToDeleteArrayItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible; 
	EndDo;	                                                                                       
	
	If ExpandFilters Then
		Alerts.AddAlert(Nstr("en='Types of ext. dimension were changed! Some filters can contains errors!';pl='Zmienili się typy analityk! Niektóre filtry mogą zawierać błędy!';ru='Типы аналитики были изменены! Некоторые фильтры могут содержать ошибки!'"));
	EndIf;	
	
	Return ExpandFilters;
		
EndFunction	

Function TrialBalanceByAccount_UpdateDependencesOnAccount(Val Account, SettingsComposer, Val FormUUID, DataCompositionSchemaAdress) Export
		
	If ValueIsNotFilled(Account) Then
		NumberOfExtDimensions =0;
		AccountCurrency = False;
	Else
		NumberOfExtDimensions = Account.ExtDimensionTypes.Count();
		AccountCurrency = Account.Currency;
	EndIf;
	
	FiltersListToUnset = New ValueList();
	
	DataCompositionSchema = Reports.TrialBalanceByAccount.GetTemplate("MainDataCompositionSchema");
	
	FieldsArray = New Array();
	FieldsArray.Add(DataCompositionSchema.DataSets[0]);
	FieldsArray.Add(DataCompositionSchema.DataSets[1]);
	
	For Each DataSet In FieldsArray Do
		
		FoundField = DataSet.Fields.Find("Currency");
		If FoundField <> Undefined Then
			
			If NOT FoundField.UseRestriction.Condition AND NOT AccountCurrency
				AND FiltersListToUnset.FindByValue(FoundField.Field) = Undefined Then
				FiltersListToUnset.Add(FoundField.Field);
			EndIf;	
			
			FoundField.UseRestriction.Condition = NOT AccountCurrency;
			FoundField.AttributeUseRestriction.Condition = NOT AccountCurrency;
			
			FoundField.UseRestriction.Group = NOT AccountCurrency;
			FoundField.AttributeUseRestriction.Group = NOT AccountCurrency;
			
		EndIf;	
		
			For i = 1 To Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount Do
				
				IsExtDimAvailable = (NumberOfExtDimensions>=i);
				
				FoundField = DataSet.Fields.Find("ExtDimension"+i);
				If FoundField <> Undefined Then
					
					WasAdded = False;
					If NOT FoundField.UseRestriction.Condition AND NOT IsExtDimAvailable 
						AND FiltersListToUnset.FindByValue(FoundField.Field) = Undefined Then
						FiltersListToUnset.Add(FoundField.Field);
						WasAdded = True;
					EndIf;	
					
					FoundField.UseRestriction.Condition = NOT IsExtDimAvailable;
					FoundField.AttributeUseRestriction.Condition = NOT IsExtDimAvailable;
					
					FoundField.UseRestriction.Group = NOT IsExtDimAvailable;
					FoundField.AttributeUseRestriction.Group = NOT IsExtDimAvailable;
					
					If IsExtDimAvailable Then
						
						If FoundField.ValueType <> Account.ExtDimensionTypes[i-1].ExtDimensionType.ValueType
							AND NOT WasAdded 
							AND FiltersListToUnset.FindByValue(FoundField.Field) = Undefined Then
								FiltersListToUnset.Add(FoundField.Field);
						EndIf;	
						
						FoundField.Title = Account.ExtDimensionTypes[i-1].ExtDimensionType.Description;
						FoundField.ValueType = Account.ExtDimensionTypes[i-1].ExtDimensionType.ValueType;
						
					EndIf;	
					
				EndIf;	
				
			EndDo;	
		
	EndDo;	
	
	DataCompositionSchemaAdress = PutToTempStorage(DataCompositionSchema, FormUUID);	

	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	SettingsComposer.Refresh();	
	
	//ExpandFilters = False;
	//
	//For Each FilterItem In SettingsComposer.Settings.Filter.Items Do
	//	
	//	If NOT FilterItem.Use Then
	//		Continue;
	//	EndIf;	
	//	
	//	FilterItemLeftValueAsString = String(FilterItem.LeftValue);
	//	FoundDot = Find(FilterItemLeftValueAsString,".");
	//	If FoundDot>0 Then
	//		FilterItemLeftValueAsString = Left(FilterItemLeftValueAsString,FoundDot-1);	
	//	EndIf;	
	//	
	//	If FiltersListToUnset.FindByValue(FilterItemLeftValueAsString)<> Undefined Then
	//		
	//		FilterItem.Use = False;
	//		ExpandFilters = True;
	//		
	//	EndIf;	
	//	
	//EndDo;	
	//	
	//If ExpandFilters Then
	//	Alerts.AddAlert(Nstr("en='Types of ext. dimension were changed! Some filters can contains errors!';pl='Zmienili się typy analityk! Niektóre filtry mogą zawierać błędy!';ru='Типы аналитики были изменены! Некоторые фильтры могут содержать ошибки!'"));
	//EndIf;	
	//
	//Return ExpandFilters;

	ExpandFilters = False;
	
	FiltersToDeleteArray = New Array;      
	UserSettingsToDeleteArray = New Array;    
	For Each FilterItem In SettingsComposer.Settings.Filter.Items Do
		
		AvailableField = SettingsComposer.Settings.FilterAvailableFields.FindField(FilterItem.LeftValue);  
		UserSettingValue = SettingsComposer.UserSettings.Items.Find(FilterItem.UserSettingID);  
		
		If AvailableField = Undefined Then           
			FiltersToDeleteArray.Add(FilterItem);      
			UserSettingsToDeleteArray.Add(UserSettingValue);  
			ExpandFilters = True;                         
		EndIf;	
		
		If NOT FilterItem.Use Then
			Continue;
		EndIf;	
		
		FilterItemLeftValueAsString = String(FilterItem.LeftValue);
		FoundDot = Find(FilterItemLeftValueAsString,".");
		If FoundDot>0 Then
			FilterItemLeftValueAsString = Left(FilterItemLeftValueAsString,FoundDot-1);	
		EndIf;	
		
		If FiltersListToUnset.FindByValue(FilterItemLeftValueAsString)<> Undefined
			OR (AvailableField <> Undefined AND NOT AvailableField.ValueType.ContainsType(TypeOf(FilterItem.RightValue))) Then    
			
			FilterItem.Use = False;
			
			If UserSettingValue <> Undefined Then 
				UserSettingValue.Use = False;                             
				UserSettingValue.UserSettingPresentation = "";                   
				UserSettingValue.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;       
				FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Normal;                    
				FilterItem.RightValue = AvailableField.ValueType.AdjustValue(FilterItem.RightValue);     
				UserSettingValue.RightValue = AvailableField.ValueType.AdjustValue(UserSettingValue.RightValue);     
			EndIf;                                                                                     

			ExpandFilters = True;
			
		EndIf;	
		
	EndDo;	
	
	For Each FiltersToDeleteArrayItem In FiltersToDeleteArray Do      
		SettingsComposer.Settings.Filter.Items.Delete(FilterItem);   
	EndDo;                                                            
	
	For Each UserSettingsToDeleteArrayItem In UserSettingsToDeleteArray Do   
		UserSettingsToDeleteArrayItem.Use = False;                           
		UserSettingsToDeleteArrayItem.UserSettingID = "";                    
		UserSettingsToDeleteArrayItem.RightValue = Undefined;                 
		UserSettingsToDeleteArrayItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible; 
	EndDo;	                                                                                       
	
	If ExpandFilters Then
		Alerts.AddAlert(Nstr("en='Types of ext. dimension were changed! Some filters can contains errors!';pl='Zmienili się typy analityk! Niektóre filtry mogą zawierać błędy!';ru='Типы аналитики были изменены! Некоторые фильтры могут содержать ошибки!'"));
	EndIf;	
	
	Return ExpandFilters;

		
EndFunction	
