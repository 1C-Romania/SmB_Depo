#Region ChartOfAccountsFilling

Procedure FillChartOfAccountsFromTemplate()
	
	ChartOfAccountManager	= ChartsOfAccounts.Managerial;
	Template 				= ChartOfAccountManager.GetTemplate("ChartOfAccountsByDefault");
	
	AccountsArray	= New Array;
	
	AccountTypes = New Map;
	AccountTypes.Insert("A" , AccountType.Active);
	AccountTypes.Insert("P" , AccountType.Passive);
	AccountTypes.Insert("AP", AccountType.ActivePassive);
	
	FieldsStructure = "ParentCode
	                 |,Code
					 |,Order
					 |,Description
					 |,Type
					 |,OffBalance
					 |,Currency
					 |,TypeOfAccount
					 |,MethodOfDistribution
					 |,Predefined"; 
	
	CurString = 2;
	
	TestValue1 = TrimAll(Template.Area(CurString, 2, CurString, 2).Text);
	TestValue2 = TrimAll(Template.Area(CurString, 10, CurString, 10).Text);
	GoOn = ValueIsFilled(TestValue1) Or ValueIsFilled(TestValue2);
	While GoOn Do
		
		Data = New Structure(FieldsStructure);
		Iterator = 1;
		For Each KeyAndValue in Data Do
			
			FieldName  = KeyAndValue.Key;
			Value = TrimAll(Template.Area(CurString, Iterator, CurString, Iterator).Text);
			If FieldName = "Type" Then
				CurrentType      = AccountTypes[Value];	
				Data[FieldName] = ?(CurrentType = Undefined, AccountType.ActivePassive, CurrentType);
			ElsIf FieldName = "TypeOfAccount" Then
				If ValueIsFilled(Value) Then
					Data[FieldName]	= Enums.GLAccountsTypes[Value];
				Else
					Data[FieldName]	= Enums.GLAccountsTypes.EmptyRef();
				EndIf;
			ElsIf FieldName = "MethodOfDistribution" Then
				If ValueIsFilled(Value) Then
					Data[FieldName]	= Enums.CostingBases[Value];
				Else
					Data[FieldName]	= Enums.CostingBases.EmptyRef();
				EndIf;
			ElsIf FieldName  = "OffBalance" 
				or FieldName = "Currency" Then	
				Data[FieldName] = ?(Value = "1", True, False);	  
			Else
				Data[FieldName] = Value;
			EndIf; 
			
			Iterator = Iterator + 1;
		EndDo; 
		
		Data.Insert("Parent");
		Data.Insert("CurrentItem");
		Data.Insert("PredefinedRef");
		
		Data.Parent			= ?(ValueIsFilled(Data.ParentCode),ChartOfAccountManager.FindByCode(Data.ParentCode), ChartsOfAccounts.Managerial.EmptyRef());
		Data.CurrentItem	= ChartOfAccountManager.FindByCode(Data.Code);
		
		If ValueIsFilled(Data.Predefined) Then
			Data.PredefinedRef	= ChartOfAccountManager[Data.Predefined];	
		Else
			Data.PredefinedRef	= ChartOfAccountManager.EmptyRef();
		EndIf;
		
		
		If ValueIsFilled(Data.PredefinedRef) Then
			ObjAccount = Data.PredefinedRef.GetObject();
		ElsIf ValueIsFilled(Data.CurrentItem) Then
			ObjAccount = Data.CurrentItem.GetObject();
		Else	
			ObjAccount = ChartOfAccountManager.CreateAccount();
		EndIf; 
		
        If ValueIsFilled(Data.Parent) And Not ValueIsFilled(Data.Code) Then
            ObjAccount.Parent	= Data.Parent;
        Else
    		FillPropertyValues(ObjAccount,Data);
        EndIf;
		
		ObjAccount.Write();
        
        CurString	= CurString + 1;				
        TestValue1	= TrimAll(Template.Area(CurString, 2, CurString, 2).Text);
        TestValue2	= TrimAll(Template.Area(CurString, 10, CurString, 10).Text);
        GoOn		= ValueIsFilled(TestValue1) Or ValueIsFilled(TestValue2);
        
	EndDo;
	
EndProcedure // FillChartOfAccountsFromTemplate()

Procedure FillChartOfAccountsByDefault() Export

	FillChartOfAccountsFromTemplate();														
	
EndProcedure // FillChartOfAccountsByDefault()

#EndRegion