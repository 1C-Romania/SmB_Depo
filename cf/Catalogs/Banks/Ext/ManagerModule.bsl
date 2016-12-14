#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface
	
// Function generates query result by
// banks classifier with filter by Code, correspondent account, name or city
//
// Parameters:
// Code - String (9) - Bank
// code BalancedAccount - String (20) - Correspondent account of the bank
//
// Returns:
// QueryResult - Query result by classifier.
//
Function GetQueryResultByClassifier(Code, CorrAccount) Export
	
	If IsBlankString(Code) AND IsBlankString(CorrAccount) Then
		Query = New Query;
		Return Query.Execute().Select();
	EndIf;
	
	QueryBuilder = New QueryBuilder;
	QueryBuilder.Text =
	"SELECT
	|	BanksClassifier.Code AS Code,
	|	BanksClassifier.Description,
	|	BanksClassifier.CorrAccount,
	|	BanksClassifier.City,
	|	BanksClassifier.Address,
	|	BanksClassifier.Ref
	|FROM
	|	Catalog.RFBankClassifier AS BanksClassifier
	|WHERE
	|	Not BanksClassifier.IsFolder
	|{WHERE
	|	BanksClassifier.Code,
	|	BanksClassifier.CorrAccount}
	|{ORDER BY
	|	Description}";
	
	Filter = QueryBuilder.Filter;
	
	If ValueIsFilled(Code) Then
		Filter.Add("Code");
		Filter.Code.Value = TrimAll(Code);
		Filter.Code.ComparisonType = ComparisonType.Contains;
		Filter.Code.Use = True;
	EndIf;
	
	If ValueIsFilled(CorrAccount) Then
		Filter.Add("CorrAccount");
		Filter.CorrAccount.Value = TrimAll(CorrAccount);
		Filter.CorrAccount.ComparisonType = ComparisonType.Contains;
		Filter.CorrAccount.Use = ValueIsFilled(CorrAccount);
	EndIf;
	
	Order = QueryBuilder.Order;
	Order.Add("Description");
	
	QueryBuilder.Execute();
	QueryResult = QueryBuilder.Result;
	
	Return QueryResult;
	
EndFunction

// Function receives references table for banks by Code or correspondent account.
//
// Parameters:
// Field - String - Field name (Code
// or CorrAccount) Value - String - Value Code or Correspondent account
//
// Returns:
// ValueTable - Found banks
//
Function GetBanksTableByAttributes(Field, Value) Export
	
	BanksTable = New ValueTable;
	Columns = BanksTable.Columns;
	Columns.Add("Ref");
	Columns.Add("Code");
	Columns.Add("CorrAccount");
	
	ThisIsCode = False;
	ThisIsCorrAccount = False;
	If Find(Field, "Code") <> 0 Then
		ThisIsCode = True;
	ElsIf Find(Field, "CorrAccount") <> 0 Then
		ThisIsCorrAccount = True;
	EndIf;
	
	If ThisIsCode AND StrLen(Value) > 6
		OR ThisIsCorrAccount AND StrLen(Value) > 10 Then
		
		If ThisIsCode Then
			
			QueryResult = GetDataFromBanks(Value, "");
			
		ElsIf ThisIsCorrAccount Then
			
			QueryResult = GetDataFromBanks("", Value);
			
		EndIf;
		
		If Not QueryResult.IsEmpty() Then
			
			Selection = QueryResult.Select();
			While Selection.Next() Do
				
				NewRow = BanksTable.Add();
				FillPropertyValues(NewRow, Selection);
				
			EndDo;
			
		EndIf;
		
		If BanksTable.Count() = 0 Then
			
			AddBanksFromClassifier(
				?(ThisIsCode, Value, ""), // Code
				?(ThisIsCorrAccount, Value, ""), // CorrAccount
				BanksTable
			);
			
		EndIf;
		
	EndIf;
	
	Return BanksTable;
	
EndFunction

// Procedure initializes banks list update.
//
Procedure RefreshBanksFromClassifier(ParametersStructure, StorageAddress) Export
	
	BanksArray        = New Array();
	DataForFilling = New Structure();
	
	SuccessfullyUpdated = WorkWithBanksOverridable.RefreshBanksFromClassifier(,
		CommonUse.SessionSeparatorValue());
	
	DataForFilling.Insert("SuccessfullyUpdated",   SuccessfullyUpdated);
	PutToTempStorage(DataForFilling, StorageAddress);
	
EndProcedure // UpdateBanksFromClassifier()

#EndRegion 

#Region ServiceProceduresAndFunctions

// Procedure adds new bank
// from classifier by Code value or correspondent account.
//
// Parameters:
// Code - String (9) - Bank
// code CorrAccount - String (20) - Correspondent
// account of the BanksTable bank account - ValueTable - Banks table
//
Procedure AddBanksFromClassifier(Code, CorrAccount, BanksTable)
	
	SetPrivilegedMode(True);

	QueryResult = GetQueryResultByClassifier(Code, CorrAccount);
	
	BanksClassifierArray = New Array;
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		BanksClassifierArray.Add(Selection.Ref);
	EndDo;
	
	If BanksClassifierArray.Count() > 0 Then
		
		BanksArray = WorkWithBanksOverridable.BankClassificatorSelection(BanksClassifierArray);
		
	Else
		
		Return;
		
	EndIf;
	
	BankFound = False;
	For Each FoundBank IN BanksArray Do
		
		SearchByCode		= Not IsBlankString(Code) AND Not FoundBank.IsFolder;
		SearchForCorrAccount	= Not IsBlankString(CorrAccount) AND Not FoundBank.IsFolder;
		
		If SearchByCode 
			AND SearchForCorrAccount
			AND FoundBank.Code = Code 
			AND FoundBank.CorrAccount = CorrAccount Then
			
			BankFound = True;
			
		ElsIf SearchByCode 
			AND Find(FoundBank.Code, Code) > 0 Then
			
			BankFound = True;
			
		ElsIf SearchForCorrAccount 
			AND Find(FoundBank.CorrAccount, CorrAccount) Then
			
			BankFound = True;
			
		EndIf;
		
		If BankFound Then
			
			NewRow = BanksTable.Add();
			FillPropertyValues(NewRow, FoundBank);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns data source focusing on the configuration work mode
// 
Function GetDataSource()
	
	Query = New Query("Select * From Catalog.Banks");
	Return Query.Execute();
	
EndFunction // GetDataArea()

// Add report builder filter item
//
Procedure AddFilterItemOfFilterBuilder(Builder, Name, Value, ComparisonTypeValue)
	
	If ValueIsFilled(Value) Then
		
		FilterItem = Builder.Filter.Add(Name);
		
	Else
		
		Return;
		
	EndIf;
	
	FilterItem.ComparisonType = ComparisonTypeValue;
	FilterItem.Value = Value;
	FilterItem.Use = True;
	
EndProcedure //AddFilterBuilderFilterItem()

// Function generates query result by
// banks classifier with filter by Code, correspondent account, bank name, city
//
// - data separation is enabled, data source is banks classifier catalog.
// - data separation is not enabled, data source is template attached to banks catalog
//
// Parameters:
// Code - String (9) - Bank
// code BalancedAccount - String (20) - Correspondent account of the bank
//
// Returns:
// QueryResult - Query result by classifier.
//
Function GetDataFromBanks(Code, CorrAccount)
	
	Builder = New QueryBuilder;
	Builder.DataSource = New DataSourceDescription(GetDataSource());
	
	AddFilterItemOfFilterBuilder(Builder, "Code", 		TrimAll(Code), 		ComparisonType.Contains);
	AddFilterItemOfFilterBuilder(Builder, "CorrAccount", TrimAll(CorrAccount),	ComparisonType.Contains);
	
	Builder.Execute();
	
	Return Builder.Result;
	
EndFunction // GetQueryResultByClassifierInSeparatedMode()

#EndRegion 

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf