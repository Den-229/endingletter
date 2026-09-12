#!/usr/bin/env python3
"""
Génère assets/categories/enable_categories.json : un mapping mot → catégorie
uniquement pour les mots qui sont dans la Enable Word List.

Catégories : animals, food, verbs, geography, body, colors, family.
"""

import json
import urllib.request

ENABLE_URL = "https://raw.githubusercontent.com/dolph/dictionary/master/enable1.txt"
OUT_PATH = "/home/asus/Documents/endingletter/assets/categories/enable_categories.json"

# Listes minimales de mots catégorisés (à enrichir au besoin).
# Tous les mots sont en minuscules.
CATEGORIES = {
    "animals": [
        "aardvark", "alligator", "alpaca", "ant", "anteater", "antelope", "ape", "armadillo",
        "baboon", "badger", "bat", "bear", "beaver", "bee", "bison", "boar", "buffalo",
        "camel", "canary", "caribou", "cat", "caterpillar", "cheetah", "chimpanzee",
        "chinchilla", "cobra", "cougar", "cow", "coyote", "crab", "crane", "crocodile",
        "crow", "deer", "dingo", "dog", "dolphin", "donkey", "dragonfly", "duck",
        "eagle", "eel", "elephant", "elk", "emu", "falcon", "ferret", "fish", "flamingo",
        "fox", "frog", "gazelle", "gecko", "giraffe", "goat", "goose", "gorilla",
        "hamster", "hare", "hawk", "hedgehog", "hen", "heron", "hippopotamus", "horse",
        "hyena", "iguana", "impala", "jaguar", "jellyfish", "kangaroo", "koala",
        "leopard", "lion", "lizard", "llama", "lobster", "lynx", "monkey", "moose",
        "mosquito", "mouse", "mule", "narwhal", "newt", "octopus", "ostrich", "otter",
        "owl", "ox", "panda", "panther", "parrot", "peacock", "pelican", "penguin",
        "pheasant", "pig", "pony", "porcupine", "possum", "puma", "quail", "rabbit",
        "raccoon", "ram", "rat", "raven", "reindeer", "rhino", "salamander", "salmon",
        "scorpion", "seal", "shark", "sheep", "shrimp", "skunk", "sloth", "snail",
        "snake", "sparrow", "spider", "squid", "squirrel", "stork", "swan", "tapir",
        "tiger", "toad", "toucan", "turkey", "turtle", "vulture", "walrus", "wasp",
        "weasel", "whale", "wolf", "wolverine", "wombat", "woodpecker", "worm", "yak",
        "zebra",
    ],
    "food": [
        "apple", "apricot", "artichoke", "asparagus", "avocado", "bacon", "bagel",
        "banana", "barley", "basil", "bean", "beef", "beet", "berry", "biscuit",
        "blueberry", "bread", "broccoli", "broth", "burger", "butter", "cabbage",
        "cake", "candy", "cantaloupe", "carrot", "cashew", "cauliflower", "celery",
        "cheese", "cherry", "chestnut", "chicken", "chickpea", "chili", "chocolate",
        "cinnamon", "coconut", "coffee", "cookie", "corn", "crab", "cranberry",
        "cucumber", "cupcake", "curry", "custard", "doughnut", "dumpling", "egg",
        "eggplant", "fig", "fish", "flour", "garlic", "ginger", "grape", "grapefruit",
        "gravy", "ham", "hamburger", "honey", "hummus", "ice", "iceberg", "jam",
        "kale", "ketchup", "kiwi", "lamb", "lasagna", "lemon", "lettuce", "lime",
        "lobster", "lychee", "macaron", "mango", "maple", "margarine", "mayonnaise",
        "meat", "melon", "milk", "mint", "mushroom", "mussel", "mustard", "noodle",
        "nut", "oat", "oatmeal", "octopus", "oil", "olive", "omelet", "onion", "orange",
        "oregano", "oyster", "pancake", "papaya", "parsley", "pasta", "peach", "peanut",
        "pear", "pepper", "pickle", "pie", "pineapple", "pizza", "plum", "pomegranate",
        "popcorn", "pork", "potato", "pretzel", "pumpkin", "quiche", "quinoa", "radish",
        "raspberry", "rice", "rosemary", "rye", "saffron", "salad", "salmon", "salsa",
        "sandwich", "sauce", "sausage", "scallop", "shrimp", "soup", "soy", "spaghetti",
        "spinach", "squash", "steak", "strawberry", "sugar", "sushi", "syrup", "taco",
        "tangerine", "tea", "thyme", "toast", "tofu", "tomato", "tortilla", "truffle",
        "tuna", "turkey", "turnip", "vanilla", "veal", "vinegar", "waffle", "walnut",
        "watermelon", "wheat", "yogurt", "zucchini",
    ],
    "geography": [
        "afghanistan", "africa", "alaska", "albania", "algeria", "america", "andorra",
        "angola", "antarctica", "argentina", "arizona", "armenia", "asia", "australia",
        "austria", "bangladesh", "belgium", "bolivia", "brazil", "britain", "bulgaria",
        "california", "cambodia", "canada", "chicago", "chile", "china", "colombia",
        "costa", "cuba", "cyprus", "czech", "denmark", "dominican", "ecuador", "egypt",
        "elsalvador", "england", "estonia", "ethiopia", "europe", "fiji", "finland",
        "florida", "france", "georgia", "germany", "ghana", "greece", "guatemala",
        "haiti", "hawaii", "holland", "honduras", "hungary", "iceland", "india",
        "indonesia", "iran", "iraq", "ireland", "israel", "italy", "jamaica", "japan",
        "jordan", "kazakhstan", "kenya", "korea", "kuwait", "laos", "latvia",
        "lebanon", "libya", "lithuania", "luxembourg", "madagascar", "malawi", "malaysia",
        "maldives", "mali", "malta", "mexico", "miami", "mongolia", "morocco",
        "mozambique", "namibia", "nepal", "netherlands", "nicaragua", "nigeria",
        "norway", "ohio", "oman", "pakistan", "panama", "paraguay", "peru", "philippines",
        "poland", "portugal", "qatar", "romania", "russia", "rwanda", "samoa", "scotland",
        "senegal", "serbia", "singapore", "slovakia", "slovenia", "somalia", "spain",
        "sudan", "sweden", "switzerland", "syria", "taiwan", "tajikistan", "tanzania",
        "texas", "thailand", "tibet", "togo", "tunisia", "turkey", "uganda", "ukraine",
        "uruguay", "utah", "uzbekistan", "venezuela", "vietnam", "wales", "washington",
        "yemen", "zambia", "zimbabwe",
    ],
    "body": [
        "ankle", "arm", "armpit", "back", "beard", "belly", "blood", "bone", "brain",
        "brow", "calf", "cheek", "chest", "chin", "ear", "elbow", "eye", "eyebrow",
        "eyelash", "eyelid", "face", "finger", "fist", "foot", "forearm", "forehead",
        "gum", "hair", "hand", "head", "heel", "hip", "jaw", "knee", "knuckle", "leg",
        "lip", "mouth", "muscle", "nail", "neck", "nerve", "nose", "nostril", "palm",
        "rib", "scalp", "shin", "shoulder", "skeleton", "skin", "skull", "spine",
        "spine", "stomach", "tendon", "thigh", "throat", "thumb", "toe", "tongue",
        "tooth", "wrist",
    ],
    "colors": [
        "aqua", "beige", "black", "blue", "bronze", "brown", "burgundy", "cerulean",
        "chartreuse", "coral", "crimson", "cyan", "emerald", "fuchsia", "gold",
        "golden", "gray", "green", "grey", "indigo", "ivory", "jade", "khaki",
        "lavender", "lilac", "magenta", "maroon", "mauve", "mustard", "navy",
        "ochre", "olive", "orange", "peach", "pink", "plum", "purple", "red",
        "rose", "ruby", "rust", "salmon", "scarlet", "sepia", "silver", "tan",
        "teal", "turquoise", "violet", "white", "yellow",
    ],
    "family": [
        "aunt", "baby", "brother", "cousin", "dad", "daughter", "father", "grandfather",
        "grandma", "grandmother", "grandpa", "grandparent", "husband", "infant",
        "mom", "mother", "nephew", "niece", "parent", "sister", "son", "twin",
        "uncle", "wife",
    ],
}

def main():
    print("📥 Téléchargement de la Enable Word List…")
    with urllib.request.urlopen(ENABLE_URL) as r:
        enable_words = {line.strip().lower() for line in r.read().decode().splitlines() if line.strip()}
    print(f"✅ {len(enable_words)} mots Enable chargés")

    mapping = {}
    counts = {cat: 0 for cat in CATEGORIES}
    for cat, words in CATEGORIES.items():
        for w in words:
            if w in enable_words:
                mapping[w] = cat
                counts[cat] += 1
    print(f"🏷️  Mapping : {sum(counts.values())} mots catégorisés ({counts})")

    with open(OUT_PATH, "w") as f:
        json.dump({"version": 1, "categories": mapping}, f, separators=(",", ":"))

    import os
    print(f"✅ Fichier écrit : {OUT_PATH} ({os.path.getsize(OUT_PATH)} octets)")

if __name__ == "__main__":
    main()