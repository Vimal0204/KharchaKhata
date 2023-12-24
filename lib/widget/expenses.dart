import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kharcha_khata/drawer/main_drawer.dart';
import 'package:kharcha_khata/model/expense.dart';
import 'package:kharcha_khata/widget/chart/chart.dart';
import 'package:kharcha_khata/widget/expenses_list/expenses_list.dart';
import 'package:kharcha_khata/widget/new_expense.dart';
import 'package:http/http.dart' as http;

class Expenses extends StatefulWidget {
  const Expenses({super.key});

  @override
  State<Expenses> createState() {
    return _ExpensesState();
  }
}

class _ExpensesState extends State<Expenses> {
  @override
  void initState() {
    _loadItem();
    _loadAmount();
    super.initState();
  }

  Map<String, int> map = {};
  String? _error;
  String? _amountError;
  var isLoading = true;
  String totalAmount = "";
  List<Expense> _registeredExpenses = [];
  void _loadAmount() async {
    final url = Uri.https(
      "kharchakhata.azurewebsites.net",
      '/api/amount/${FirebaseAuth.instance.currentUser?.uid}',
    );
    try {
      final response = await http.get(
        url,
      );
      if (response.statusCode >= 400) {
        setState(() {
          _amountError = 'Failed to fetch the data. Please try again later...';
        });
      }
      if (response.body == 'null') {
        setState(() {
          totalAmount = '0';
        });
        return;
      }
      final amount = json.decode(response.body);
      setState(() {
        totalAmount = amount.toStringAsFixed(5);
        // isLoading = false;
      });
    } catch (error) {
      setState(() {
        _amountError = '0';
      });
    }
  }

  void _loadItem() async {
    final url = Uri.https(
      "kharchakhata.azurewebsites.net",
      '/api/expenses/${FirebaseAuth.instance.currentUser?.uid}',
    );
    try {
      final response = await http.get(
        url,
      );
      if (response.statusCode >= 400) {
        setState(() {
          _error = 'Failed to fetch the data. Please try again later...';
        });
      }
      if (response.body == 'null') {
        setState(() {
          isLoading = false;
        });
        return;
      }
      final List<dynamic> listData = json.decode(response.body);
      final List<Expense> loadedItem = [];
      for (final element in listData) {
        loadedItem.add(
          Expense(
            title: element['expenseName'],
            amount: element['expenseAmount'],
            date: DateTime.parse(element['expenseDate']),
            category: Category.values.firstWhere(
              (elem) =>
                  elem.name == element['expenseType'].toString().toLowerCase(),
            ),
          ),
        );
        String expenseId = loadedItem.elementAt(loadedItem.length - 1).id;
        map.addAll({expenseId: element['id']});
      }

      _registeredExpenses = loadedItem;

      setState(() {
        isLoading = false;
      });
    } catch (error) {
      setState(
        () {
          _error = 'Something went wrong with the server!';
        },
      );
    }
  }

  void _openAddExpenseOverlay() {
    showModalBottomSheet(
      useSafeArea: true,
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.cyan,
      builder: (ctx) => NewExpense(
        onAddExpense: _addExpense,
        onLoadAmount: _loadAmount,
        onloadItem: _loadItem,
      ),
    );
  }

  void _addExpense(Expense expense) async {
    _registeredExpenses.add(expense);
    setState(
      () async {
        _loadItem();
        _loadAmount();
      },
    );
  }

  void _onRemoveExpense(Expense expense) async {
    var undo = false;
    final expenseIndex = _registeredExpenses.indexOf(expense);
    int deleteId =
        map.entries.firstWhere((element) => element.key == expense.id).value;
    setState(
      () {
        _registeredExpenses.remove(expense);
      },
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: const Text('Expense deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _registeredExpenses.insert(expenseIndex, expense);
            });
            undo = true;
          },
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 5), () async {
      if (undo == false) {
        final url = Uri.https(
          "kharchakhata.azurewebsites.net",
          '/api/expenses/${FirebaseAuth.instance.currentUser?.uid}/$deleteId',
        );
        await http.delete(
          url,
        );
        setState(
          () {
            _loadAmount();
          },
        );
        map.remove(expense.id);
      }
    });
  }

  void _onSelectOption(String identifier) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    Widget mainContent = Center(
      child: Text(
        'No Expense found. Try adding some!',
        style: Theme.of(context).textTheme.titleLarge!.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
      ),
    );
    if (isLoading) {
      mainContent = const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      mainContent = Center(
        child: Text(
          _error!,
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
        ),
      );
    }
    if (_registeredExpenses.isNotEmpty) {
      mainContent = ExpensesList(
        expenses: _registeredExpenses,
        onRemoveExpense: _onRemoveExpense,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kharcha Khata'),
        actions: [
          IconButton(
            onPressed: _openAddExpenseOverlay,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      drawer: MainDrawer(
        onSelectOption: _onSelectOption,
        userName: FirebaseAuth.instance.currentUser?.displayName,
      ),
      body: width < 600
          ? Column(
              children: [
                // toolbar with add buuton=> row().
                Chart(expenses: _registeredExpenses),
                Expanded(
                  child: mainContent,
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 40,
                    ),
                    child: Row(
                      children: [
                        Text(
                          "Total Expenses : ",
                          style:
                              Theme.of(context).textTheme.titleLarge!.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                  ),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        (_amountError != null)
                            ? Text(
                                _amountError!,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge!
                                    .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                              )
                            : Text(
                                totalAmount,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge!
                                    .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Chart(
                    expenses: _registeredExpenses,
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 40,
                    ),
                    child: Row(
                      children: [
                        Text(
                          "Total Expenses : ",
                          style:
                              Theme.of(context).textTheme.titleLarge!.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                  ),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          totalAmount,
                          style:
                              Theme.of(context).textTheme.titleLarge!.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: mainContent,
                ),
              ],
            ),
    );
  }
}
