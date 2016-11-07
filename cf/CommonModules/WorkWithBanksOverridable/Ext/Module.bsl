////////////////////////////////////////////////////////////////////////////////
// Subsystem "Banks".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// It enables/disables the display of warnings showing the need to update the bank classifier.
//
// Parameters:
//  ShowMessageBox - Boolean.
Procedure OnDeterminingWhetherToShowWarningsAboutOutdatedClassifierBanks(ShowMessageBox) Export
	
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// SB. SERVICE PROCEDURES AND FUNCTIONS

// Update banks of the classifier and also set
// the current state (ManualChanging attribute). We are searching for the link by BIC and CorrAccount (for items only).
// You shall update only that items which attribute
// does not match the same attribute in the classifier
//
// Parameters:
//
//  - BankList - Array - items with the CatalogRef.RFBanksClassifier type - the list of
//                       banks to be updated if the list is empty, then it is necessary to check all items and update the changed ones
//
//  - DataArea - Number(1, 0) - data area to be updated for
//                              the local mode = 0 if the data area is not transferred, the update is not performed.
//
Function RefreshBanksFromClassifier(Val BankList = Undefined, Val DataArea) Export
	
	AreaProcessed  = True;
	If DataArea = Undefined Then
		Return AreaProcessed;
	EndIf;
	
	Query = New Query;
	QueryText =
	"SELECT
	|	RFBankClassifier.Code AS Code,
	|	RFBankClassifier.CorrAccount AS CorrAccount,
	|	RFBankClassifier.Description,
	|	RFBankClassifier.City,
	|	RFBankClassifier.Address,
	|	RFBankClassifier.PhoneNumbers,
	|	RFBankClassifier.IsFolder,
	|	RFBankClassifier.Parent.Code,
	|	RFBankClassifier.Parent.Description,
	|	RFBankClassifier.ActivityDiscontinued
	|INTO TU_ChangedBanks
	|FROM
	|	Catalog.RFBankClassifier AS RFBankClassifier
	|WHERE
	|	RFBankClassifier.Ref IN(&BankList)
	|
	|INDEX BY
	|	Code,
	|	CorrAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	SubqueryBanks.Bank AS Bank,
	|	SubqueryBanks.Code AS Code,
	|	SubqueryBanks.CorrAccount AS CorrAccount,
	|	SubqueryBanks.Description AS Description,
	|	SubqueryBanks.City AS City,
	|	SubqueryBanks.Address AS Address,
	|	SubqueryBanks.PhoneNumbers AS PhoneNumbers,
	|	SubqueryBanks.IsFolder AS IsFolder,
	|	SubqueryBanks.ParentCode AS ParentCode,
	|	SubqueryBanks.ParentDescription AS ParentDescription,
	|	SubqueryBanks.ActivityDiscontinued AS ActivityDiscontinued
	|INTO TU_ChangedItems
	|FROM
	|	(SELECT
	|		Banks.Ref AS Bank,
	|		TU_ChangedBanks.Code AS Code,
	|		TU_ChangedBanks.CorrAccount AS CorrAccount,
	|		TU_ChangedBanks.Description AS Description,
	|		TU_ChangedBanks.City AS City,
	|		TU_ChangedBanks.Address AS Address,
	|		TU_ChangedBanks.PhoneNumbers AS PhoneNumbers,
	|		TU_ChangedBanks.IsFolder AS IsFolder,
	|		TU_ChangedBanks.ParentCode AS ParentCode,
	|		TU_ChangedBanks.ParentDescription AS ParentDescription,
	|		TU_ChangedBanks.ActivityDiscontinued AS ActivityDiscontinued
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.CorrAccount = TU_ChangedBanks.CorrAccount
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.Description <> TU_ChangedBanks.Description
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.CorrAccount,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.PhoneNumbers,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.ActivityDiscontinued
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.CorrAccount = TU_ChangedBanks.CorrAccount
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.City <> TU_ChangedBanks.City
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.CorrAccount,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.PhoneNumbers,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.ActivityDiscontinued
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.CorrAccount = TU_ChangedBanks.CorrAccount
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.Address <> TU_ChangedBanks.Address
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.CorrAccount,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.PhoneNumbers,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.ActivityDiscontinued
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.CorrAccount = TU_ChangedBanks.CorrAccount
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.PhoneNumbers <> TU_ChangedBanks.PhoneNumbers
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.CorrAccount,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.PhoneNumbers,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.ActivityDiscontinued
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.CorrAccount = TU_ChangedBanks.CorrAccount
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.Parent.Code <> TU_ChangedBanks.ParentCode
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.CorrAccount,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.PhoneNumbers,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.ActivityDiscontinued
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.CorrAccount = TU_ChangedBanks.CorrAccount
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND (Banks.ManualChanging = 2)
	|	WHERE
	|		Not Banks.IsFolder) AS SubqueryBanks
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_ChangedItems.Bank AS Bank,
	|	TU_ChangedItems.Code AS Code,
	|	TU_ChangedItems.CorrAccount AS CorrAccount,
	|	TU_ChangedItems.Description AS Description,
	|	TU_ChangedItems.City AS City,
	|	TU_ChangedItems.Address AS Address,
	|	TU_ChangedItems.PhoneNumbers AS PhoneNumbers,
	|	TU_ChangedItems.IsFolder AS IsFolder,
	|	0 AS ManualChanging,
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)) AS Parent,
	|	TU_ChangedItems.ParentCode AS ParentCode,
	|	TU_ChangedItems.ParentDescription AS ParentDescription,
	|	TU_ChangedItems.ActivityDiscontinued AS ActivityDiscontinued
	|FROM
	|	TU_ChangedItems AS TU_ChangedItems
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON TU_ChangedItems.ParentCode = Banks.Code
	|
	|UNION ALL
	|
	|SELECT
	|	Banks.Ref,
	|	TU_ChangedBanks.Code,
	|	NULL,
	|	TU_ChangedBanks.Description,
	|	NULL,
	|	NULL,
	|	NULL,
	|	TU_ChangedBanks.IsFolder,
	|	0,
	|	NULL,
	|	NULL,
	|	NULL,
	|	TU_ChangedBanks.ActivityDiscontinued
	|FROM
	|	Catalog.Banks AS Banks
	|		INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|		ON Banks.Code = TU_ChangedBanks.Code
	|			AND Banks.Description <> TU_ChangedBanks.Description
	|			AND (Banks.ManualChanging = 0)
	|WHERE
	|	TU_ChangedBanks.IsFolder
	|
	|UNION ALL
	|
	|SELECT
	|	Banks.Ref,
	|	TU_ChangedBanks.Code,
	|	NULL,
	|	TU_ChangedBanks.Description,
	|	NULL,
	|	NULL,
	|	NULL,
	|	TU_ChangedBanks.IsFolder,
	|	0,
	|	NULL,
	|	NULL,
	|	NULL,
	|	TU_ChangedBanks.ActivityDiscontinued
	|FROM
	|	Catalog.Banks AS Banks
	|		INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|		ON Banks.Code = TU_ChangedBanks.Code
	|			AND (Banks.ManualChanging = 2)
	|WHERE
	|	TU_ChangedBanks.IsFolder
	|
	|ORDER BY
	|	IsFolder DESC";
	
	If BankList = Undefined OR BankList.Count() = 0 Then
		QueryText = StrReplace(QueryText, "
			|WHERE
			|	RFBanksClassifier.Ref IN(&BankList)", "");
	Else
		Query.SetParameter("BankList",  BankList);
	EndIf;
	
	Query.Text  = QueryText;
	BanksSelection = Query.Execute().Select();
	
	ExcludingPropertiesForItem = "IsFolder";
	ExcludingPropertiesForGroup   = "Address, City, CorrAccount, PhoneNumbers, Parent, IsFolder";
	
	While BanksSelection.Next() Do
		
		Bank = BanksSelection.Bank.GetObject();
		FillPropertyValues(Bank, BanksSelection,,
			?(BanksSelection.IsFolder, ExcludingPropertiesForGroup, ExcludingPropertiesForItem));
		
		If Not BanksSelection.IsFolder AND Not ValueIsFilled(BanksSelection.Parent) AND Not IsBlankString(BanksSelection.ParentCode) Then
			Parent = RefOnBank(BanksSelection.ParentCode, True);
			If Not ValueIsFilled(Parent) Then
				Parent = Catalogs.Banks.CreateFolder();
				Parent.Code          = BanksSelection.ParentCode;
				Parent.Description = BanksSelection.ParentDescription;
				
				Try
					Parent.Write();
				Except
					MessagePattern   = NStr("en='Error when recording the bank-group (state) %1.
		|%2';ru='Ошибка при записи банка-группы (региона) %1.
		|%2'");
					MessageText    = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
						BanksSelection.ParentDescription,
					DetailErrorDescription(ErrorInfo()));
					DataAreaNumber      = ?(CommonUseReUse.DataSeparationEnabled(),
						StringFunctionsClientServer.PlaceParametersIntoString(NStr("en=' in area %1';ru=' в области %1'"), DataArea),
						"");
					EventName        = StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='Banks refresh %1';ru='Обновление банков%1'"), DataAreaNumber);
					WriteLogEvent(EventName, 
						EventLogLevel.Error,,, MessageText);
					
					AreaProcessed = False;
					Break;
				EndTry
			EndIf;
			
			Bank.Parent = Parent.Ref;
		EndIf;
		
		Try
			Bank.Write();
		Except
			MessagePattern   = NStr("en='Error when recording the bank
		|with BIC %1 %2';ru='Ошибка при записи
		|банка с БИКом %1 %2'");
			MessageText    = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
				BanksSelection.Code,
				DetailErrorDescription(ErrorInfo()));
			DataAreaNumber      = ?(CommonUseReUse.DataSeparationEnabled(),
				StringFunctionsClientServer.PlaceParametersIntoString(NStr("en=' in area %1';ru=' в области %1'"), DataArea),
				"");
			EventName        = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Banks refresh %1';ru='Обновление банков%1'"), DataAreaNumber);
			WriteLogEvent(EventName, 
			EventLogLevel.Error,,, MessageText);
			
			AreaProcessed = False;
		EndTry;
		
	EndDo;
	
	If Not AreaProcessed Then
		Return AreaProcessed;
	EndIf;
	
	// Find banks with the lost classifier
	// connection and set the appropriate sign
	Query = New Query;
	Query.Text =
	"SELECT
	|	Banks.Ref AS Bank,
	|	2 AS ManualChanging
	|FROM
	|	Catalog.Banks AS Banks
	|		LEFT JOIN Catalog.RFBankClassifier AS RFBankClassifier
	|		ON Banks.Code = RFBankClassifier.Code
	|			AND (Banks.IsFolder
	|				OR Banks.CorrAccount = RFBankClassifier.CorrAccount)
	|WHERE
	|	RFBankClassifier.Ref IS NULL 
	|	AND Banks.ManualChanging <> 2
	|
	|UNION
	|
	|SELECT
	|	Banks.Ref,
	|	3
	|FROM
	|	Catalog.Banks AS Banks
	|		LEFT JOIN Catalog.RFBankClassifier AS RFBankClassifier
	|		ON Banks.Code = RFBankClassifier.Code
	|			AND (Banks.IsFolder
	|				OR Banks.CorrAccount = RFBankClassifier.CorrAccount)
	|WHERE
	|	RFBankClassifier.ActivityDiscontinued
	|	AND Banks.ManualChanging < 2";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Bank = Selection.Bank.GetObject();
		Bank.ManualChanging = Selection.ManualChanging;
		
		Try
			Bank.Write();
		Except
			MessagePattern   = NStr("en='Error when recording the bank
		|with BIC %1 %2';ru='Ошибка при записи
		|банка с БИКом %1 %2'");
			MessageText    = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
				BanksSelection.Code,
				DetailErrorDescription(ErrorInfo()));
			DataAreaNumber      = ?(CommonUseReUse.DataSeparationEnabled(),
				StringFunctionsClientServer.PlaceParametersIntoString(NStr("en ' in %1 field'"), DataArea),
				"");
			EventName        = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Banks refresh %1';ru='Обновление банков%1'"), DataAreaNumber);
			WriteLogEvent(EventName, 
			EventLogLevel.Error,,, MessageText);
			
			AreaProcessed = False;
		EndTry;
		
	EndDo;
	
	Return AreaProcessed;
	
EndFunction

// Specifies the text of the
// divided object state, sets the availability of the state control buttons and ReadOnly flag form
//
Procedure ProcessManualEditFlag(Val Form)
	
	Items  = Form.Items;
	
	If Form.ManualChanging = Undefined Then
		If Form.ActivityDiscontinued Then
			Form.ManualEditText = "";
		Else
			Form.ManualEditText = NStr("en='The item is created manually. Automatic update is impossible.';ru='Элемент создан вручную. Автоматическое обновление не возможно.'");
		EndIf;
		
		Items.UpdateFromClassifier.Enabled = False;
		Items.Change.Enabled = False;
		Form.ReadOnly          = False;
		Items.Parent.Enabled = True;
		Items.Code.Enabled      = True;
		If Not Form.Object.IsFolder Then
			Items.CorrAccount.Enabled = True;
		EndIf;
	ElsIf Form.ManualChanging = True Then
		Form.ManualEditText = NStr("en='Automatic item update is disabled.';ru='Автоматическое обновление элемента отключено.'");
		
		Items.UpdateFromClassifier.Enabled = True;
		Items.Change.Enabled = False;
		Form.ReadOnly          = False;
		Items.Parent.Enabled = False;
		Items.Code.Enabled      = False;
		If Not Form.Object.IsFolder Then
			Items.CorrAccount.Enabled = False;
		EndIf;
	Else
		Form.ManualEditText = NStr("en='Item is updated automatically.';ru='Элемент обновляется автоматически.'");
		
		Items.UpdateFromClassifier.Enabled = False;
		Items.Change.Enabled = True;
		Form.ReadOnly          = True;
	EndIf;
	
EndProcedure

// It reads the object current state
// and makes the form compliant with it
//
Procedure ReadManualEditFlag(Val Form) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Banks.ManualChanging AS ManualChanging
	|FROM
	|	Catalog.Banks AS Banks
	|WHERE
	|	Banks.Ref = &Ref";
	
	Query.SetParameter("Ref", Form.Object.Ref);
	
	SetPrivilegedMode(True);
	QueryResult = Query.Execute();
	SetPrivilegedMode(False);
	
	If QueryResult.IsEmpty() Then
		
		Form.ManualChanging = Undefined;
		
	Else
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		If Selection.ManualChanging >= 2 Then
			Form.ManualChanging = Undefined;
		Else
			Form.ManualChanging = Selection.ManualChanging;
		EndIf;
		
	EndIf;
	
	If Form.ManualChanging = Undefined Then
		RefToClassifier = ReferenceOnClassifier(Form.Object.Code);
		If ValueIsFilled(RefToClassifier) Then
			Query.SetParameter("Ref", RefToClassifier);
			Query.Text =
			"SELECT
			|	RFBankClassifier.ActivityDiscontinued
			|FROM
			|	Catalog.RFBankClassifier AS RFBankClassifier
			|WHERE
			|	RFBankClassifier.Ref = &Ref";
			
			Selection = Query.Execute().Select();
			Selection.Next();
			Form.ActivityDiscontinued = Selection.ActivityDiscontinued;
		EndIf;
	EndIf;
	
	ProcessManualEditFlag(Form);
	
EndProcedure

// Function to be changed and Banks catalog record
// by transferred parameters if such bank is not
// in the base, it is created if the bank is not on the first level in the hierarchy, the whole chain of parents is created/copied
//
// Parameters:
//
// - Refs - Array with items of the Structure type - Structure keys - names of
//   the catalog attributes, Structure values - attribute data values
// - IgnoreManualChanging - Boolean - do not process banks changed manually
//   
// Returns:
//
// - Array with items of CatalogRef.Banks type
//
Function RefreshCreateBanksWIB(Refs, IgnoreManualChanging)
	
	BanksArray = New Array;
	
	For ind = 0 To Refs.UBound() Do
		ParametersObject = Refs[ind];
		Bank = ParametersObject.Bank;
		
		If ParametersObject.ManualChanging = 1
			AND Not IgnoreManualChanging Then
			BanksArray.Add(Bank);
			Continue;
		EndIf;
		
		If Bank.IsEmpty() Then
			If ParametersObject.ThisState Then
				BankObject = Catalogs.Banks.CreateFolder();
			Else
				BankObject = Catalogs.Banks.CreateItem();
			EndIf;
		Else
			BankObject = Bank.GetObject();
		EndIf;
		
		FillPropertyValues(BankObject, ParametersObject);
		If Not IsBlankString(ParametersObject.ParentCode) AND Not ValueIsFilled(ParametersObject.Parent) Then
			Region = RefOnBank(ParametersObject.ParentCode, True);
			
			If Not ValueIsFilled(Region) Then
				BanksParametersHigherInHierarchy = New Array;
				BanksParametersHigherInHierarchy.Add(ReferenceOnClassifier(ParametersObject.ParentCode));
				
				// If the transferred Parent is not
				// the root item, then the array of all items (groups) above it in the hierarchy will be returned.
				// The hierarchy root item will be at the beginning of the array, at the end of the array - item transferred in parameters 
				ArrayBanksAboveForHierarchy = BankClassificatorSelection(BanksParametersHigherInHierarchy);
				
				If ArrayBanksAboveForHierarchy.Count() > 0 Then
					// The item transferred to the parameter (to be created) in the returned Array will always be on the last position
					LastItem = ArrayBanksAboveForHierarchy.UBound();
					Region = ArrayBanksAboveForHierarchy[LastItem];
				EndIf;
			EndIf;
			
			If ValueIsFilled(Region) AND Region.IsFolder Then
				BankObject.Parent = Region;
			EndIf;
			
			If Not ValueIsFilled(BankObject.Parent) Then
				EventName = ?(EventName = "",
					NStr("en='Pick from ACC';ru='Подбор из классификатора'"), EventName);
				ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Failed to obtain the parent from the item with BIC %1';ru='Не смогли получить родителя у элемента с БИК %1'"), TrimAll(ParametersObject.Code));
				WriteLogEvent(EventName, 
					EventLogLevel.Error,,, ErrorText);
				Break;
			EndIf;
		EndIf;
		
		BeginTransaction();
		Try
			BankObject.Write();
			CommitTransaction();
		Except
			RollbackTransaction();
			
			EventName = ?(EventName = "",
				NStr("en='Pick from ACC';ru='Подбор из классификатора'"), EventName);
			WriteLogEvent(EventName, 
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			
			Break;
		EndTry;
		
		BanksArray.Add(BankObject.Ref);
	EndDo;
	
	Return BanksArray;
	
EndFunction

// The function selects the classifier data to be copied to
// the Banks catalog item if such bank is
// not in the base, it is created if the bank is not on the first level in the hierarchy, the whole chain of parents is created/copied
//
// Parameters:
//
// - BankReferences - Array with items of CatalogRef.RFBanksClassifier type - the list
//   of classifier values to be processed
// - IgnoreManualChanging - Boolean - do not process banks changed manually
//
// Returns:
//
// - Array with items of CatalogRef.Banks type
//
Function BankClassificatorSelection(Val ReferencesBanks, IgnoreManualChanging = False) Export
	
	BanksArray = New Array;
	
	If ReferencesBanks.Count() = 0 Then
		Return BanksArray;
	EndIf;
	
	LinksHierarchy = SupplementArrayWithRefParents(ReferencesBanks);
	
	Query = New Query;
	Query.SetParameter("LinksHierarchy", LinksHierarchy);
	Query.Text =
	"SELECT
	|	RFBankClassifier.Code AS BIN,
	|	RFBankClassifier.CorrAccount AS CorrAccount,
	|	RFBankClassifier.Description,
	|	RFBankClassifier.City,
	|	RFBankClassifier.Address,
	|	RFBankClassifier.PhoneNumbers,
	|	RFBankClassifier.IsFolder,
	|	RFBankClassifier.Parent.Code
	|INTO TU_RFBankClassifier
	|FROM
	|	Catalog.RFBankClassifier AS RFBankClassifier
	|WHERE
	|	RFBankClassifier.Ref IN(&LinksHierarchy)
	|
	|INDEX BY
	|	BIN,
	|	CorrAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)) AS Bank,
	|	TU_RFBankClassifier.BIN AS Code,
	|	TU_RFBankClassifier.CorrAccount AS CorrAccount,
	|	TU_RFBankClassifier.IsFolder AS ThisState,
	|	TU_RFBankClassifier.Description,
	|	TU_RFBankClassifier.City,
	|	TU_RFBankClassifier.Address,
	|	TU_RFBankClassifier.PhoneNumbers,
	|	0 AS ManualChanging,
	|	ISNULL(TU_RFBankClassifier.ParentCode, """") AS ParentCode
	|INTO BanksWithoutParents
	|FROM
	|	TU_RFBankClassifier AS TU_RFBankClassifier
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON TU_RFBankClassifier.CorrAccount = Banks.CorrAccount
	|			AND TU_RFBankClassifier.BIN = Banks.Code
	|WHERE
	|	Not TU_RFBankClassifier.IsFolder
	|
	|UNION ALL
	|
	|SELECT
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)),
	|	TU_RFBankClassifier.BIN,
	|	NULL,
	|	TU_RFBankClassifier.IsFolder,
	|	TU_RFBankClassifier.Description,
	|	NULL,
	|	NULL,
	|	NULL,
	|	0,
	|	ISNULL(TU_RFBankClassifier.ParentCode, """")
	|FROM
	|	TU_RFBankClassifier AS TU_RFBankClassifier
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON TU_RFBankClassifier.BIN = Banks.Code
	|WHERE
	|	TU_RFBankClassifier.IsFolder
	|
	|INDEX BY
	|	ParentCode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BanksWithoutParents.Bank,
	|	BanksWithoutParents.Code AS Code,
	|	BanksWithoutParents.CorrAccount,
	|	BanksWithoutParents.ThisState AS ThisState,
	|	BanksWithoutParents.Description,
	|	BanksWithoutParents.City,
	|	BanksWithoutParents.Address,
	|	BanksWithoutParents.PhoneNumbers,
	|	BanksWithoutParents.ManualChanging,
	|	BanksWithoutParents.ParentCode,
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)) AS Parent
	|FROM
	|	BanksWithoutParents AS BanksWithoutParents
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON BanksWithoutParents.ParentCode = Banks.Parent
	|
	|ORDER BY
	|	ThisState DESC,
	|	Code";
	
	SetPrivilegedMode(True);
	BanksTable = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	Refs = New Array;
	For Each ValueTableRow IN BanksTable Do
		
		ObjectParameters = CommonUse.ValueTableRowToStructure(ValueTableRow);
		DeleteNoValidKeysStructure(ObjectParameters);
		Refs.Add(ObjectParameters);
		
	EndDo;
	
	BanksArray = RefreshCreateBanksWIB(Refs, IgnoreManualChanging);
	
	Return BanksArray;
	
EndFunction

// Data recovery from the common
// object and it changes the object state
//
Procedure RestoreItemFromSharedData(Val Form) Export
	
	BeginTransaction();
	Try
		Refs = New Array;
		Classifier = ReferenceOnClassifier(
			Form.Object.Code, TrimAll(Form.Object.CorrAccount));
		
		If Not ValueIsFilled(Classifier) Then
			Return;
		EndIf;
		
		Refs.Add(Classifier);
		BankClassificatorSelection(Refs, True);
		
		Form.ManualChanging = False;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en='Recovery from common data';ru='Восстановление из общих данных'"), 
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	Form.Read();
	
EndProcedure

// Receiving the references to the RF Bank Classifier catalog item by BIC or CorrAccount text presentation
// 
Function ReferenceOnClassifier(BIN, CorrAccount = "")
	
	If BIN = "" Then
		Return Catalogs.RFBankClassifier.EmptyRef();
	EndIf;
	
	Query = New Query;
	QueryText =
	"SELECT
	|	RFBankClassifier.Ref
	|FROM
	|	Catalog.RFBankClassifier AS RFBankClassifier
	|WHERE
	|	RFBankClassifier.Code = &BIN
	|	AND RFBankClassifier.CorrAccount = &CorrAccount";
	
	Query.SetParameter("BIN", BIN);
	
	If CorrAccount = "" Then
		QueryText = StrReplace(QueryText, "AND RFBankClassifier.CorrAccount = &CorrAccount", "");
	Else
		Query.SetParameter("CorrAccount", CorrAccount);
	EndIf;
	
	Query.Text = QueryText;
	
	SetPrivilegedMode(True);
	Result = Query.Execute();
	SetPrivilegedMode(False);
	
	If Result.IsEmpty() Then
		Return Catalogs.RFBankClassifier.EmptyRef();
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction // ReferenceOnClassifier()

// Receiving the references to
// the Banks catalog item by BIC or CorrAccount text presentation
//
Function RefOnBank(BIN, ThisState = False)
	
	If BIN = "" Then
		Return Catalogs.Banks.EmptyRef();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Banks.Ref
	|FROM
	|	Catalog.Banks AS Banks
	|WHERE
	|	Banks.Code = &BIN
	|	AND Banks.IsFolder = &IsFolder";
	
	Query.SetParameter("BIN",       BIN);
	Query.SetParameter("IsFolder", ThisState);
	
	SetPrivilegedMode(True);
	Result = Query.Execute();
	SetPrivilegedMode(False);
	
	If Result.IsEmpty() Then
		Return Catalogs.Banks.EmptyRef();
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction // RefsOnBank()

Function SupplementArrayWithRefParents(Val Refs)
	
	TableName = Refs[0].Metadata().FullName();
	
	RefArray = New Array;
	For Each Ref IN Refs Do
		RefArray.Add(Ref);
	EndDo;
	
	CurrentRefs = Refs;
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	Table.Parent AS Ref
	|FROM
	|	" + TableName + " AS
	|Table
	|WHERE Table.Reference
	|	In (&Links) And Table.Parent <> VALUE(" + TableName + ".EmptyRef)";
	
	While True Do
		Query.SetParameter("Refs", CurrentRefs);
		Result = Query.Execute();
		If Result.IsEmpty() Then
			Break;
		EndIf;
		
		CurrentRefs = New Array;
		Selection = Result.Select();
		While Selection.Next() Do
			CurrentRefs.Add(Selection.Ref);
			RefArray.Add(Selection.Ref);
		EndDo;
	EndDo;
	
	Return RefArray;
	
EndFunction

Procedure DeleteNoValidKeysStructure(ParametersStructureCatalog)
	
	For Each KeyAndValue IN ParametersStructureCatalog Do
		If KeyAndValue.Value = Null OR KeyAndValue.Key = "IsFolder" Then
			ParametersStructureCatalog.Delete(KeyAndValue.Key);
		EndIf;
	EndDo;
	
EndProcedure

// It copies all banks to all DE
//
// Parameters  
//   BankTable - ValueTable with the banks
//   AreasForUpdating - Array with a list of area codes
//   FileIdentifier - File UUID for the processed banks
//   ProcessorCode  - String, handler code
//
Procedure BanksExtendedDA(Val BankList, Val FileID, Val ProcessorCode) Export
	
	AreasForUpdating  = SuppliedData.AreasRequiredProcessing(
		FileID, "RFBanks");
	
	For Each DataArea IN AreasForUpdating Do
		AreaProcessed = False;
		SetPrivilegedMode(True);
		CommonUse.SetSessionSeparation(True, DataArea);
		SetPrivilegedMode(False);
		
		BeginTransaction();
		AreaProcessed = WorkWithBanksOverridable.RefreshBanksFromClassifier(
			BankList, DataArea);
		
		If AreaProcessed Then
			SuppliedData.AreaProcessed(FileID, ProcessorCode, DataArea);
			CommitTransaction();
		Else
			RollbackTransaction();
		EndIf;
		
	EndDo;
	
EndProcedure

// It loads the bank classifier in the service model from the provided data
//
// Parameters:
//   PathToFile - String - bnk.zip file path received from the provided data
//
Function ImportSuppliedRFBankClassifier(PathToFile) Export
	
	Return WorkWithBanks.ImportDataFromRBKFile(PathToFile);
	
EndFunction



