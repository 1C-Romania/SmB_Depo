
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServerNoContext
// It receives data set from server for the DateOnChange procedure.
//
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	StructureData = New Structure();
	StructureData.Insert("DATEDIFF", SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange));
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

&AtServerNoContext
// Gets data set from server.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", SmallBusinessServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

&AtServerNoContext
// Receives a quotation from the server.
//
Function GetQuote(StructureData)
	
	StructureData.Insert("Characteristic", Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
	StructureData.Insert("AmountIncludesVAT", StructureData.PriceKind.PriceIncludesVAT);
	StructureData.Insert("DocumentCurrency", StructureData.PriceKind.PriceCurrency);
	StructureData.Insert("Factor", 1);
	
	StructureData.Insert("Price", SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData));
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()	

&AtClient
// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
Procedure CalculateTotal()

	CurrentRow = Items.Operations.CurrentData;
	CurrentRow.Total = CurrentRow.MoDuration + CurrentRow.TuDuration + CurrentRow.WeDuration 
							+ CurrentRow.ThDuration + CurrentRow.FrDuration + CurrentRow.SaDuration  
							+ CurrentRow.SuDuration;
	CurrentRow.Amount = CurrentRow.Tariff * CurrentRow.Total;
		
EndProcedure

&AtClient
// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
Function CalculateDuration(BeginTime, EndTime)
	
	DurationInSeconds = EndTime - BeginTime;	
	Return Round(DurationInSeconds / 3600, 2);
	
EndFunction

&AtClient
// The procedure sets the headers of columns.
//
// Parameters:
//  No.
//
Procedure SetColumnHeaders()

	Items.OperationsMonDuration.Title = NStr("en='Mo ';ru='Пн '") + Format(Object.DateFrom, "DF=dd.MM");
	Items.OperationsTuDuration.Title = NStr("en='Tu ';ru='Вт '") + Format(Object.DateFrom + 86400, "DF=dd.MM");
	Items.OperationsAverageDuration.Title = NStr("en='We ';ru='Ср '") + Format(Object.DateFrom + 86400*2, "DF=dd.MM");
	Items.OperationsThDuration.Title = NStr("en='Th ';ru='Чт '") + Format(Object.DateFrom + 86400*3, "DF=dd.MM");
	Items.OperationsFrDuration.Title = NStr("en='Fr ';ru='Пт '") + Format(Object.DateFrom + 86400*4, "DF=dd.MM");
	Items.OperationsSaDuration.Title = NStr("en='Sa ';ru='Сб '") + Format(Object.DateFrom + 86400*5, "DF=dd.MM");
	Items.OperationsSuDuration.Title = NStr("en='Su ';ru='Вс '") + Format(Object.DateFrom + 86400*6, "DF=dd.MM");

EndProcedure

&AtServer
// The procedure fills in a tabular section by planning data.
//
// Parameters:
//  No.
//
Procedure FillByPlanAtServer()

	Query = New Query("SELECT
	                      |	JobOrderWorks.WorkKind AS WorkKind,
	                      |	JobOrderWorks.Customer AS Customer,
	                      |	JobOrderWorks.ProductsAndServices AS ProductsAndServices,
	                      |	JobOrderWorks.Characteristic AS Characteristic,
	                      |	JobOrderWorks.Ref.PriceKind AS PriceKind,
	                      |	JobOrderWorks.Price AS Price,
	                      |	JobOrderWorks.DurationInHours AS Duration,
	                      |	JobOrderWorks.BeginTime AS BeginTime,
	                      |	JobOrderWorks.EndTime AS EndTime,
	                      |	WeekDay(JobOrderWorks.Day) AS WeekDay
	                      |FROM
	                      |	Document.WorkOrder.Works AS JobOrderWorks,
	                      |	Constants AS Constants
	                      |WHERE
	                      |	JobOrderWorks.Day between &DateFrom AND &DateTo
	                      |	AND CASE
	                      |			WHEN Constants.AccountingBySubsidiaryCompany
	                      |				THEN Constants.SubsidiaryCompany = &Company
	                      |			ELSE JobOrderWorks.Ref.Company = &Company
	                      |		END
	                      |	AND JobOrderWorks.Ref.StructuralUnit = &StructuralUnit
	                      |	AND JobOrderWorks.Ref.Employee = &Employee
	                      |	AND JobOrderWorks.DurationInHours > 0
	                      |
	                      |ORDER BY
	                      |	WorkKind,
	                      |	Customer,
	                      |	ProductsAndServices,
	                      |	Characteristic,
	                      |	PriceKind,
	                      |	Price,
	                      |	WeekDay,
	                      |	BeginTime,
	                      |	EndTime
	                      |TOTALS BY
	                      |	WorkKind,
	                      |	Customer,
	                      |	ProductsAndServices,
	                      |	Characteristic,
	                      |	PriceKind,
	                      |	Price");	
	
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Object.Company));
	Query.SetParameter("StructuralUnit", Object.StructuralUnit);
	Query.SetParameter("Employee", Object.Employee);
	Query.SetParameter("DateFrom", BegOfDay(Object.DateFrom));
	Query.SetParameter("DateTo", EndOfDay(Object.DateTo));
	
	SelectionWorkKind = Query.Execute().Select(QueryResultIteration.ByGroups, "WorkKind");
	
	WeekDays = New Map;
	WeekDays.Insert(1, "Mo");
	WeekDays.Insert(2, "Tu");
	WeekDays.Insert(3, "We");
	WeekDays.Insert(4, "Th");
	WeekDays.Insert(5, "Fr");
	WeekDays.Insert(6, "Sa");
	WeekDays.Insert(7, "Su");
	
	While SelectionWorkKind.Next() Do
		CustomerSelection = SelectionWorkKind.Select(QueryResultIteration.ByGroups, "Customer");
		While CustomerSelection.Next() Do
			SelectionProductsAndServices = CustomerSelection.Select(QueryResultIteration.ByGroups, "ProductsAndServices");
			While SelectionProductsAndServices.Next() Do
		    	SelectionCharacteristic = SelectionProductsAndServices.Select(QueryResultIteration.ByGroups, "Characteristic");
				While SelectionCharacteristic.Next() Do
		        	SelectionPriceKind = SelectionCharacteristic.Select(QueryResultIteration.ByGroups, "PriceKind");
					While SelectionPriceKind.Next() Do
		            	SelectionPrice = SelectionPriceKind.Select(QueryResultIteration.ByGroups, "Price");
						While SelectionPrice.Next() Do
							
							FirstIndex = Undefined;
							LastIndex = Undefined;
						
						 	Selection = SelectionPrice.Select();
							While Selection.Next() Do
							
								If FirstIndex = Undefined Then
									
									NewRow = Object.Operations.Add();
									NewRow.WorkKind 		= Selection.WorkKind;
									NewRow.Customer 		= Selection.Customer;
									NewRow.ProductsAndServices 	= Selection.ProductsAndServices;
									NewRow.Characteristic 	= Selection.Characteristic;
									NewRow.PriceKind 			= Selection.PriceKind;
									NewRow.Tariff 		= Selection.Price;
									NewRow[WeekDays.Get(Selection.WeekDay) + "Duration"] 	= Selection.Duration;
									NewRow[WeekDays.Get(Selection.WeekDay) + "BeginTime"] 	= Selection.BeginTime;
									NewRow[WeekDays.Get(Selection.WeekDay) + "EndTime"] 	= Selection.EndTime;
									NewRow.Total = Selection.Duration;
									NewRow.Amount = NewRow.Total * NewRow.Tariff;				
									
									FirstIndex = Object.Operations.IndexOf(NewRow);
									LastIndex = FirstIndex;
								
								Else
									
									StringFound = False;
									
									For Counter = FirstIndex To LastIndex Do
										
										CurrentRow = Object.Operations.Get(Counter);
										
										If CurrentRow[WeekDays.Get(Selection.WeekDay) + "Duration"] = 0 Then
										
											CurrentRow[WeekDays.Get(Selection.WeekDay) + "Duration"] = Selection.Duration;
											CurrentRow[WeekDays.Get(Selection.WeekDay) + "BeginTime"] = Selection.BeginTime;
											CurrentRow[WeekDays.Get(Selection.WeekDay) + "EndTime"] = Selection.EndTime;
											CurrentRow.Total = CurrentRow.Total + Selection.Duration;
											CurrentRow.Amount = CurrentRow.Total * CurrentRow.Tariff;
											
											StringFound = True;
											
											Break;
										
										EndIf;
									
									EndDo;
									
									If Not StringFound Then
									
										NewRow = Object.Operations.Add();
										NewRow.WorkKind 		= Selection.WorkKind;
										NewRow.Customer 		= Selection.Customer;
										NewRow.ProductsAndServices 	= Selection.ProductsAndServices;
										NewRow.Characteristic 	= Selection.Characteristic;
										NewRow.PriceKind 			= Selection.PriceKind;
										NewRow.Tariff 		= Selection.Price;
										NewRow[WeekDays.Get(Selection.WeekDay) + "Duration"] 	= Selection.Duration;
										NewRow[WeekDays.Get(Selection.WeekDay) + "BeginTime"] 	= Selection.BeginTime;
										NewRow[WeekDays.Get(Selection.WeekDay) + "EndTime"] 	= Selection.EndTime;
										NewRow.Total = Selection.Duration;
										NewRow.Amount = NewRow.Total * NewRow.Tariff;				
										
										LastIndex = Object.Operations.IndexOf(NewRow);	
									
									EndIf; 
									
								EndIf;
							
							EndDo;		
		 
						EndDo;
						
					EndDo;
					
				EndDo;
				
			EndDo;
			
		EndDo;
						
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS
            
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed,
	Parameters.FillingValues);
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	Items.OperationsMonDuration.Title = NStr("en='Mo ';ru='Пн '") + Format(Object.DateFrom, "DF=dd.MM");
	Items.OperationsTuDuration.Title = NStr("en='Tu ';ru='Вт '") + Format(Object.DateFrom + 86400, "DF=dd.MM");
	Items.OperationsAverageDuration.Title = NStr("en='We ';ru='Ср '") + Format(Object.DateFrom + 86400*2, "DF=dd.MM");
	Items.OperationsThDuration.Title = NStr("en='Th ';ru='Чт '") + Format(Object.DateFrom + 86400*3, "DF=dd.MM");
	Items.OperationsFrDuration.Title = NStr("en='Fr ';ru='Пт '") + Format(Object.DateFrom + 86400*4, "DF=dd.MM");
	Items.OperationsSaDuration.Title = NStr("en='Sa ';ru='Сб '") + Format(Object.DateFrom + 86400*5, "DF=dd.MM");
	Items.OperationsSuDuration.Title = NStr("en='Su ';ru='Вс '") + Format(Object.DateFrom + 86400*6, "DF=dd.MM");
	
	If Not Constants.FunctionalOptionUseJobSharing.Get() Then
		If Items.Find("EmployeeCode") <> Undefined Then		
			Items.EmployeeCode.Visible = False;		
		EndIf;
	EndIf;
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure // OnReadAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure // DateOnChange()

&AtClient
// Procedure - event handler OnChange of the Company input field.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure // CompanyOnChange()

&AtClient
// Procedure - OnChange event processor of DateFrom and DateUntil attribute.
//
Procedure DateFromOnChange(Item)
	
	Object.DateFrom 	= BegOfWeek(Object.DateFrom);
	Object.DateTo 	= EndOfWeek(Object.DateFrom);
	
	SetColumnHeaders();
	
EndProcedure

&AtClient
// Procedure - OnChange event processor of DateFrom and DateUntil attribute.
//
Procedure DateToOnChange(Item)
	
	Object.DateFrom 	= BegOfWeek(Object.DateTo);
	Object.DateTo 	= EndOfWeek(Object.DateTo);
	
	SetColumnHeaders();
	
EndProcedure

&AtClient
// Procedure - command handler FillInByPlan.
//
Procedure FillByPlan(Command)
	
	If Not ValueIsFilled(Object.Company) Then
        Message = New UserMessage();
		Message.Text = NStr("en='Company is not populated. Population is canceled.';ru='Не заполнена организация! Заполнение отменено.'");
		Message.Field = "Object.Company";
		Message.Message();
		Return;
	EndIf;

	If Not ValueIsFilled(Object.StructuralUnit) Then
        Message = New UserMessage();
		Message.Text = NStr("en='Department is not populated. Population is canceled.';ru='Не заполнено подразделение! Заполнение отменено.'");
		Message.Field = "Object.StructuralUnit";
		Message.Message();
		Return;
	EndIf;

	If Not ValueIsFilled(Object.Employee) Then
        Message = New UserMessage();
		Message.Text = NStr("en='Employee is not selected. Population is canceled.';ru='Не выбран сотрудник! Заполнение отменено.'");
		Message.Field = "Object.Employee";
		Message.Message();
		Return;
	EndIf;

	If Not ValueIsFilled(Object.DateFrom) Then
        Message = New UserMessage();
		Message.Text = NStr("en='Week start is not selected. Population is canceled.';ru='Не выбрано начало недели! Заполнение отменено.'");
		Message.Field = "Object.DateFrom";
		Message.Message();
		Return;
	EndIf;

	If Not ValueIsFilled(Object.DateTo) Then
        Message = New UserMessage();
		Message.Text = NStr("en='Week end is not selected. Population is canceled.';ru='Не выбрано окончание недели! Заполнение отменено.'");
		Message.Field = "Object.DateTo";
		Message.Message();
		Return;
	EndIf;

	If Object.Operations.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillInByPlanEnd", ThisObject), NStr("en='Tabular section of the document will be cleared. Continue?';ru='Табличная часть документа будет очищена! Продолжить?'"), QuestionDialogMode.YesNo, 0);
        Return; 
	EndIf;
	
	FillInByPlanFragment();
EndProcedure

&AtClient
Procedure FillInByPlanEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf; 
    
    FillInByPlanFragment();

EndProcedure

&AtClient
Procedure FillInByPlanFragment()
    
    Object.Operations.Clear();
    FillByPlanAtServer();

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

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABLE PARTS ATTRIBUTE EVENT HANDLERS

&AtClient
// Procedure - OnChange event handler of WorkKind attribute of Operations tabular section.
//
Procedure OperationsWorksKindOnChange(Item)
	
	CurrentRow = Items.Operations.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("ProductsAndServices", 	CurrentRow.WorkKind);	
	StructureData.Insert("PriceKind", 			CurrentRow.PriceKind);	
	StructureData.Insert("ProcessingDate", 	DocumentDate);
	CurrentRow.Tariff = GetQuote(StructureData).Price;
	CurrentRow.Amount = CurrentRow.Tariff * CurrentRow.Total;
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of Tariff attribute of Operations tabular section.
//
Procedure OperationsTariffOnChange(Item)
	
	CurrentRow = Items.Operations.CurrentData;
	CurrentRow.Amount = CurrentRow.Tariff * CurrentRow.Total;
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the Amount attribute of the Operations tabular section.
//
Procedure OperationsAmountOnChange(Item)
	
	CurrentRow = Items.Operations.CurrentData;
	CurrentRow.Tariff = ?(CurrentRow.Total = 0, 0, CurrentRow.Amount / CurrentRow.Total);
	
EndProcedure

&AtClient
// Procedure - SelectionStart event handler of Comment attribute of Operations tabular section.
//
Procedure OperationsCommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Operations.CurrentData;
	FormParameters = New Structure("Text, Title", CurrentData.Comment, "Comment edit");  
	ReturnComment = Undefined;
  
	OpenForm("CommonForm.TextEdit", FormParameters,,,,, New NotifyDescription("OperationsCommentStartChoiceEnd", ThisObject, New Structure("CurrentData", CurrentData))); 
	
EndProcedure

&AtClient
Procedure OperationsCommentStartChoiceEnd(Result, AdditionalParameters) Export
    
    CurrentData = AdditionalParameters.CurrentData;
    
    
    ReturnComment = Result;
    
    If TypeOf(ReturnComment) = Type("String") Then
        
        If CurrentData.Comment <> ReturnComment Then
            Modified = True;
        EndIf;
        
        CurrentData.Comment = ReturnComment;
        
    EndIf;

EndProcedure

&AtClient
// Procedure - OnChange event handler of Duration attribute of Operations tabular section.
//
Procedure OperationsMoDurationOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.MoDuration * 3600;	
	CurrentData.MoEndTime = CurrentData.MoBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.MoBeginTime < DurationInSeconds Then	
		CurrentData.MoEndTime = '00010101235959';
		CurrentData.MoDuration = CalculateDuration(CurrentData.MoBeginTime, CurrentData.MoEndTime);		
	EndIf;
	
	CalculateTotal();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of BeginTime attribute of Operations tabular section.
//
Procedure OperationsMoWithOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.MoDuration * 3600;	
	CurrentData.MoEndTime = CurrentData.MoBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.MoBeginTime < DurationInSeconds Then	
		CurrentData.MoEndTime = '00010101235959';
		CurrentData.MoDuration = CalculateDuration(CurrentData.MoBeginTime, CurrentData.MoEndTime);		
		CalculateTotal(); 
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of EndTime attribute of Operations tabular section.
//
Procedure OperationsMoByOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	If CurrentData.MoBeginTime > CurrentData.MoEndTime Then
		CurrentData.MoBeginTime = CurrentData.MoEndTime;
	EndIf; 
	
	CurrentData.MoDuration = CalculateDuration(CurrentData.MoBeginTime, CurrentData.MoEndTime);
	CalculateTotal(); 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of Duration attribute of Operations tabular section.
//
Procedure OperationsTuDurationOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.TuDuration * 3600;	
	CurrentData.TuEndTime = CurrentData.TuBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.TuBeginTime < DurationInSeconds Then	
		CurrentData.TuEndTime = '00010101235959';
		CurrentData.TuDuration = CalculateDuration(CurrentData.TuBeginTime, CurrentData.TuEndTime);		
	EndIf;
	
	CalculateTotal();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of BeginTime attribute of Operations tabular section.
//
Procedure OperationsTuFromOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.TuDuration * 3600;	
	CurrentData.TuEndTime = CurrentData.TuBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.TuBeginTime < DurationInSeconds Then	
		CurrentData.TuEndTime = '00010101235959';
		CurrentData.TuDuration = CalculateDuration(CurrentData.TuBeginTime, CurrentData.TuEndTime);		
		CalculateTotal(); 
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of EndTime attribute of Operations tabular section.
//
Procedure OperationsTuToOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	If CurrentData.TuBeginTime > CurrentData.TuEndTime Then
		CurrentData.TuBeginTime = CurrentData.TuEndTime;
	EndIf; 
	
	CurrentData.TuDuration = CalculateDuration(CurrentData.TuBeginTime, CurrentData.TuEndTime);
	CalculateTotal(); 
	
EndProcedure
&AtClient
// Procedure - OnChange event handler of Duration attribute of Operations tabular section.
//
Procedure OperationsWeDurationOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.WeDuration * 3600;	
	CurrentData.WeEndTime = CurrentData.WeBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.WeBeginTime < DurationInSeconds Then	
		CurrentData.WeEndTime = '00010101235959';
		CurrentData.WeDuration = CalculateDuration(CurrentData.WeBeginTime, CurrentData.WeEndTime);		
	EndIf;
	
	CalculateTotal();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of BeginTime attribute of Operations tabular section.
//
Procedure OperationsWeWithOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.WeDuration * 3600;	
	CurrentData.WeEndTime = CurrentData.WeBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.WeBeginTime < DurationInSeconds Then	
		CurrentData.WeEndTime = '00010101235959';
		CurrentData.WeDuration = CalculateDuration(CurrentData.WeBeginTime, CurrentData.WeEndTime);		
		CalculateTotal(); 
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of EndTime attribute of Operations tabular section.
//
Procedure OperationsWeByOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	If CurrentData.WeBeginTime > CurrentData.WeEndTime Then
		CurrentData.WeBeginTime = CurrentData.WeEndTime;
	EndIf; 
	
	CurrentData.WeDuration = CalculateDuration(CurrentData.WeBeginTime, CurrentData.WeEndTime);
	CalculateTotal(); 
	
EndProcedure
&AtClient
// Procedure - OnChange event handler of Duration attribute of Operations tabular section.
//
Procedure OperationsThDurationOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.ThDuration * 3600;	
	CurrentData.ThEndTime = CurrentData.ThBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.ThBeginTime < DurationInSeconds Then	
		CurrentData.ThEndTime = '00010101235959';
		CurrentData.ThDuration = CalculateDuration(CurrentData.ThBeginTime, CurrentData.ThEndTime);		
	EndIf;
	
	CalculateTotal();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of BeginTime attribute of Operations tabular section.
//
Procedure OperationsThWithOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.ThDuration * 3600;	
	CurrentData.ThEndTime = CurrentData.ThBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.ThBeginTime < DurationInSeconds Then	
		CurrentData.ThEndTime = '00010101235959';
		CurrentData.ThDuration = CalculateDuration(CurrentData.ThBeginTime, CurrentData.ThEndTime);		
		CalculateTotal(); 
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of EndTime attribute of Operations tabular section.
//
Procedure OperationsThByOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	If CurrentData.ThBeginTime > CurrentData.ThEndTime Then
		CurrentData.ThBeginTime = CurrentData.ThEndTime;
	EndIf; 
	
	CurrentData.ThDuration = CalculateDuration(CurrentData.ThBeginTime, CurrentData.ThEndTime);
	CalculateTotal(); 
	
EndProcedure
&AtClient
// Procedure - OnChange event handler of Duration attribute of Operations tabular section.
//
Procedure OperationsFrDurationOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.FrDuration * 3600;	
	CurrentData.FrEndTime = CurrentData.FrBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.FrBeginTime < DurationInSeconds Then	
		CurrentData.FrEndTime = '00010101235959';
		CurrentData.FrDuration = CalculateDuration(CurrentData.FrBeginTime, CurrentData.FrEndTime);		
	EndIf;
	
	CalculateTotal();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of BeginTime attribute of Operations tabular section.
//
Procedure OperationsFrWithOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.FrDuration * 3600;	
	CurrentData.FrEndTime = CurrentData.FrBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.FrBeginTime < DurationInSeconds Then	
		CurrentData.FrEndTime = '00010101235959';
		CurrentData.FrDuration = CalculateDuration(CurrentData.FrBeginTime, CurrentData.FrEndTime);		
		CalculateTotal(); 
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of EndTime attribute of Operations tabular section.
//
Procedure OperationsFrByOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	If CurrentData.FrBeginTime > CurrentData.FrEndTime Then
		CurrentData.FrBeginTime = CurrentData.FrEndTime;
	EndIf; 
	
	CurrentData.FrDuration = CalculateDuration(CurrentData.FrBeginTime, CurrentData.FrEndTime);
	CalculateTotal(); 
	
EndProcedure
&AtClient
// Procedure - OnChange event handler of Duration attribute of Operations tabular section.
//
Procedure OperationsSaDurationOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.SaDuration * 3600;	
	CurrentData.SaEndTime = CurrentData.SaBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.SaBeginTime < DurationInSeconds Then	
		CurrentData.SaEndTime = '00010101235959';
		CurrentData.SaDuration = CalculateDuration(CurrentData.SaBeginTime, CurrentData.SaEndTime);		
	EndIf;
	
	CalculateTotal();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of BeginTime attribute of Operations tabular section.
//
Procedure OperationsSaWithOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.SaDuration * 3600;	
	CurrentData.SaEndTime = CurrentData.SaBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.SaBeginTime < DurationInSeconds Then	
		CurrentData.SaEndTime = '00010101235959';
		CurrentData.SaDuration = CalculateDuration(CurrentData.SaBeginTime, CurrentData.SaEndTime);		
		CalculateTotal(); 
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of EndTime attribute of Operations tabular section.
//
Procedure OperationsSaByOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	If CurrentData.SaBeginTime > CurrentData.SaEndTime Then
		CurrentData.SaBeginTime = CurrentData.SaEndTime;
	EndIf; 
	
	CurrentData.SaDuration = CalculateDuration(CurrentData.SaBeginTime, CurrentData.SaEndTime);
	CalculateTotal(); 
	
EndProcedure
&AtClient
// Procedure - OnChange event handler of Duration attribute of Operations tabular section.
//
Procedure OperationsSuDurationOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.SuDuration * 3600;	
	CurrentData.SuEndTime = CurrentData.SuBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.SuBeginTime < DurationInSeconds Then	
		CurrentData.SuEndTime = '00010101235959';
		CurrentData.SuDuration = CalculateDuration(CurrentData.SuBeginTime, CurrentData.SuEndTime);		
	EndIf;
	
	CalculateTotal();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of BeginTime attribute of Operations tabular section.
//
Procedure OperationsSuFromOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.SuDuration * 3600;	
	CurrentData.SuEndTime = CurrentData.SuBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.SuBeginTime < DurationInSeconds Then	
		CurrentData.SuEndTime = '00010101235959';
		CurrentData.SuDuration = CalculateDuration(CurrentData.SuBeginTime, CurrentData.SuEndTime);		
		CalculateTotal(); 
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of EndTime attribute of Operations tabular section.
//
Procedure OperationsSuToOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	If CurrentData.SuBeginTime > CurrentData.SuEndTime Then
		CurrentData.SuBeginTime = CurrentData.SuEndTime;
	EndIf; 
	
	CurrentData.SuDuration = CalculateDuration(CurrentData.SuBeginTime, CurrentData.SuEndTime);
	CalculateTotal(); 
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of attribute Customer.
//
Procedure OperationsConsumerChoiceProcessingChoice(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected = Type("CatalogRef.CounterpartyContracts") Then
	
		StandardProcessing = False;
		
		SelectedContract = Undefined;

		
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceFormWithCounterparty",,,,,, New NotifyDescription("OperationsCustomerChoiceChoiceProcessingEnd", ThisObject));
	
	EndIf;	
	
EndProcedure

&AtClient
Procedure OperationsCustomerChoiceChoiceProcessingEnd(Result, AdditionalParameters) Export
    
    SelectedContract = Result;
    
    If TypeOf(SelectedContract) = Type("CatalogRef.CounterpartyContracts")Then
        Items.Operations.CurrentData.Customer = SelectedContract;
    EndIf;

EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentTimeTrackingPosting");
	// StandardSubsystems.PerformanceEstimation
	
EndProcedure // BeforeWrite()

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion



