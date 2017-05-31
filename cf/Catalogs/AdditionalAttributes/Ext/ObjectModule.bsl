
Procedure BeforeWrite(Cancel)
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Query = New Query;
	
	Query.Text = 
	"SELECT
	|	AdditionalAttributes.Ref
	|FROM
	|	Catalog.AdditionalAttributes AS AdditionalAttributes
	|WHERE
	|	AdditionalAttributes.Description = &Description
	|	AND AdditionalAttributes.Ref <> &CurrentRef
	|	AND AdditionalAttributes.DeletionMark = FALSE";
	
	Query.SetParameter("Description", Description);
	Query.SetParameter("CurrentRef", Ref);
	
	QueryResult = Query.Execute();
	If NOT QueryResult.IsEmpty() then
		Cancel = True;
		Message(Nstr("en='Element with same description already exist';pl='Atrybut z takim opisem już istnieje';ru='Атрибут с данным наименованием уже существует'"));
	EndIf;	

EndProcedure
