@override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Allows map to sit behind AppBar
      extendBody: true, 
      
      // MOVED APPBAR HERE
      appBar: _currentIndex == 0 ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.person_outline, color: Colors.blue),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("SafeWalk KT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            Text("LIVE PROTECTION", style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
            icon: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.notifications, color: Colors.black)),
            onPressed: () {},
          ),
          IconButton(
            icon: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.tune, color: Colors.black)),
            onPressed: () {},
          ),
        ],
      ) : null, // Only show AppBar on the Map (Explore) tab

      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _currentIndex == 0 ? Container( // Only show button on Map tab
        height: 55,
        width: MediaQuery.of(context).size.width * 0.45,
        margin: const EdgeInsets.only(bottom: 20),
        child: FloatingActionButton.extended(
          elevation: 4,
          backgroundColor: const Color(0xFF3B71FE),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportIncidentPage()),
            );
          },
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
          label: const Text("Quick Report", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ) : null,

      bottomNavigationBar: Container(
        // ... (Keep your BottomNavigationBar code exactly as it was)